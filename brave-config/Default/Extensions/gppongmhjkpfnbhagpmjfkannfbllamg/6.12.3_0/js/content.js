'use strict'
/* eslint-env browser */
/* globals chrome, globalThis */

function yieldToMain() {
  if (globalThis?.scheduler?.yield) {
    return globalThis?.scheduler.yield()
  }

  // Fall back to yielding with setTimeout.
  return new Promise((resolve) => {
    setTimeout(resolve, 0)
  })
}

const MAX_TEXT_LENGTH = 25000
const MAX_INLINE_SCRIPT_COUNT = 50
const MAX_INLINE_SCRIPT_CHARS = 200000
const MAX_DOM_TEXT_LENGTH = 1000000
const MAX_TECH_DETECTIONS = 50
const LANGUAGE_DETECTION_SAMPLE_LENGTH = 5000
const LANGUAGE_DETECTION_MIN_TEXT_LENGTH = 250
const LANGUAGE_DETECTION_MIN_ALPHA_CHARS = 120
const LANGUAGE_DETECTION_MIN_WORDS = 20
const LANGUAGE_DETECTION_MIN_PERCENTAGE = 85
const LANGUAGE_DETECTION_MIN_MARGIN = 25
const TEXT_SKIP_TAGS = new Set([
  'script',
  'style',
  'noscript',
  'template',
  'title',
  'desc',
  'metadata',
])

function normalizeLanguageTag(value = '') {
  const tokens = `${value || ''}`
    .trim()
    .replace(/_/g, '-')
    .split('-')
    .filter(Boolean)

  const [language, ...subtags] = tokens

  if (!/^[a-z]{2}$/i.test(language || '')) {
    return ''
  }

  const region = subtags.find((subtag) => /^[a-z]{2}$/i.test(subtag))

  return `${language.toLowerCase()}${region ? `-${region.toUpperCase()}` : ''}`
}

function getBaseLanguage(value = '') {
  const language = normalizeLanguageTag(value)

  return language ? language.split('-')[0] : ''
}

function getRequiredTechnologyNames(technologies = []) {
  return [
    ...new Set(
      (Array.isArray(technologies) ? technologies : [])
        .map((technology) => technology?.name)
        .filter(Boolean)
    ),
  ]
}

function collectVisibleText(maxLength) {
  const body = document.body

  if (!body || maxLength <= 0) {
    return ''
  }

  const elementStateCache = new WeakMap()
  let text = ''
  let pendingSpace = false
  const stack = [{ node: body, exiting: false }]
  const applyTextTransform = (value, textTransform) => {
    switch (textTransform) {
      case 'uppercase':
        return value.toLocaleUpperCase()
      case 'lowercase':
        return value.toLocaleLowerCase()
      case 'capitalize':
        return value.replace(
          /(^|[^\p{L}\p{N}]+)(\p{L})/gu,
          (_, prefix, char) => `${prefix}${char.toLocaleUpperCase()}`
        )
      default:
        return value
    }
  }

  const getElementState = (element) => {
    if (!element) {
      return {
        visible: true,
        breaksText: false,
        textTransform: 'none',
      }
    }

    if (elementStateCache.has(element)) {
      return elementStateCache.get(element)
    }

    const parentState = getElementState(element.parentElement)

    let state
    const tagName = element.localName

    if (!parentState.visible || TEXT_SKIP_TAGS.has(tagName) || element.hidden) {
      state = {
        visible: false,
        breaksText: false,
        textTransform: 'none',
      }
    } else {
      const style = getComputedStyle(element)
      const visible =
        style.display !== 'none' &&
        style.visibility !== 'hidden' &&
        style.visibility !== 'collapse'

      state = {
        visible,
        breaksText:
          visible &&
          element !== body &&
          style.display !== 'contents' &&
          !style.display.startsWith('inline'),
        textTransform: style.textTransform,
      }
    }

    elementStateCache.set(element, state)

    return state
  }

  while (stack.length && text.length < maxLength) {
    const { node, exiting } = stack.pop()

    if (exiting) {
      if (node !== body && getElementState(node).breaksText && text) {
        pendingSpace = true
      }

      continue
    }

    if (node.nodeType === Node.TEXT_NODE) {
      const raw = node.textContent || ''

      if (!raw) {
        continue
      }

      const normalized = applyTextTransform(
        raw.replace(/\s+/g, ' ').trim(),
        getElementState(node.parentElement).textTransform
      )

      if (!normalized) {
        if (text && /\s/.test(raw)) {
          pendingSpace = true
        }

        continue
      }

      if (text && (pendingSpace || /^\s/.test(raw))) {
        text += ' '

        if (text.length >= maxLength) {
          break
        }
      }

      const remaining = maxLength - text.length

      text += normalized.slice(0, remaining)
      pendingSpace = /\s$/.test(raw)

      continue
    }

    if (node.nodeType !== Node.ELEMENT_NODE) {
      continue
    }

    const state = getElementState(node)

    if (!state.visible) {
      continue
    }

    if (node.localName === 'br') {
      if (text) {
        pendingSpace = true
      }

      continue
    }

    if (node !== body && state.breaksText && text) {
      pendingSpace = true
    }

    stack.push({ node, exiting: true })

    if (node.localName === 'details' && !node.open) {
      const summary = Array.from(node.children).find(
        ({ localName }) => localName === 'summary'
      )

      if (summary) {
        stack.push({ node: summary, exiting: false })
      }

      continue
    }

    for (let child = node.lastChild; child; child = child.previousSibling) {
      stack.push({ node: child, exiting: false })
    }
  }

  return text.trim()
}

function getLanguageSampleText() {
  const text = collectVisibleText(LANGUAGE_DETECTION_SAMPLE_LENGTH)

  if (text.length < LANGUAGE_DETECTION_MIN_TEXT_LENGTH) {
    return ''
  }

  const alphaChars = (text.match(/\p{L}/gu) || []).length
  const words = text.match(/\p{L}{2,}/gu) || []

  if (
    alphaChars < LANGUAGE_DETECTION_MIN_ALPHA_CHARS ||
    words.length < LANGUAGE_DETECTION_MIN_WORDS
  ) {
    return ''
  }

  return text
}

function detectLanguageFromVisibleText() {
  if (!chrome.i18n.detectLanguage) {
    return ''
  }

  const sample = getLanguageSampleText()

  if (!sample) {
    return ''
  }

  return new Promise((resolve) => {
    chrome.i18n.detectLanguage(sample, ({ languages = [] } = {}) => {
      const rankedLanguages = languages
        .map(({ language, percentage }) => ({
          language: getBaseLanguage(language),
          percentage: parseInt(percentage, 10) || 0,
        }))
        .filter(({ language }) => language)
        .sort(({ percentage: a }, { percentage: b }) => (a < b ? 1 : -1))

      const [top, next] = rankedLanguages

      if (
        !top ||
        top.percentage < LANGUAGE_DETECTION_MIN_PERCENTAGE ||
        top.percentage - (next ? next.percentage : 0) <
          LANGUAGE_DETECTION_MIN_MARGIN
      ) {
        resolve('')

        return
      }

      resolve(top.language)
    })
  })
}

function hasHeavySignals({ text = '', css = '', scripts = [] } = {}) {
  return !!(text || css || scripts.length)
}

function inject(src, id, message) {
  return new Promise((resolve) => {
    // Inject a script tag into the page to access methods of the window object
    const script = document.createElement('script')

    script.onload = () => {
      const onMessage = ({ data }) => {
        if (!data.wappalyzer || !data.wappalyzer[id]) {
          return
        }

        window.removeEventListener('message', onMessage)

        resolve(data.wappalyzer[id])

        script.remove()
      }

      window.addEventListener('message', onMessage)

      window.postMessage({
        wappalyzer: message,
      })
    }

    script.setAttribute('src', chrome.runtime.getURL(src))

    document.body.appendChild(script)
  })
}

function getJs(technologies) {
  return inject('js/js.js', 'js', {
    technologies: technologies
      .filter(({ js }) => Object.keys(js).length)
      .map(({ name, js }) => ({ name, chains: Object.keys(js) })),
  })
}

async function getDom(technologies) {
  const startTime = performance.now()
  const _technologies = technologies
    .filter(({ dom }) => dom && dom.constructor === Object)
    .map(({ name, dom }) => ({ name, dom }))

  const detections = await getDomDetections(_technologies)

  const returnVal = [
    ...(await inject('js/dom.js', 'dom', {
      technologies: _technologies.filter(({ dom }) =>
        Object.values(dom)
          .flat()
          .some(({ properties }) => properties)
      ),
    })),
    ...detections,
  ]
  performance.measure('Wappalyzer: getDom', {
    start: startTime,
    end: performance.now(),
  })
  return returnVal
}

async function getDomDetections(_technologies) {
  const technologies = []
  const detectionKeys = new Set()
  const detectionCounts = new Map()
  const selectorCache = new Map()
  let lastYield = performance.now()

  const shouldYield = () => performance.now() - lastYield > 16
  const updateYield = async () => {
    if (shouldYield()) {
      await yieldToMain()
      lastYield = performance.now()
    }
  }
  const getDetectionCount = (name) => detectionCounts.get(name) || 0
  const addDetection = (name, key, detection) => {
    if (
      detectionKeys.has(key) ||
      getDetectionCount(name) >= MAX_TECH_DETECTIONS
    ) {
      return false
    }

    detectionKeys.add(key)
    detectionCounts.set(name, getDetectionCount(name) + 1)
    technologies.push(detection)

    return true
  }

  for (const { name, dom } of _technologies) {
    const toScalar = (value) =>
      typeof value === 'string' || typeof value === 'number' ? value : !!value

    await updateYield()

    for (const selector of Object.keys(dom)) {
      if (getDetectionCount(name) >= MAX_TECH_DETECTIONS) {
        break
      }

      let nodes = []

      if (selectorCache.has(selector)) {
        nodes = selectorCache.get(selector)
      } else {
        try {
          nodes = document.querySelectorAll(selector)
        } catch (error) {
          Content.driver('error', error)
        }

        selectorCache.set(selector, nodes)
      }

      if (!nodes.length) {
        continue
      }

      for (const { exists, text, properties, attributes } of dom[selector]) {
        for (const node of nodes) {
          if (getDetectionCount(name) >= MAX_TECH_DETECTIONS) {
            break
          }

          if (exists) {
            addDetection(name, `${name}|${selector}|exists`, {
              name,
              selector,
              exists: '',
            })
          }

          if (text) {
            // eslint-disable-next-line unicorn/prefer-text-content
            const value = (node.innerText ? node.innerText.trim() : '').slice(
              0,
              MAX_DOM_TEXT_LENGTH
            )

            if (value) {
              addDetection(name, `${name}|${selector}|text|${value}`, {
                name,
                selector,
                text: value,
              })
            }
          }

          if (properties) {
            for (const property of Object.keys(properties)) {
              if (Object.prototype.hasOwnProperty.call(node, property)) {
                const value = node[property]

                if (typeof value !== 'undefined') {
                  addDetection(
                    name,
                    `${name}|${selector}|property|${property}|${toScalar(
                      value
                    )}`,
                    {
                      name,
                      selector,
                      property,
                      value: toScalar(value),
                    }
                  )
                }
              }
            }
          }

          if (attributes) {
            for (const attribute of Object.keys(attributes)) {
              if (node.hasAttribute(attribute)) {
                const value = node.getAttribute(attribute)

                addDetection(
                  name,
                  `${name}|${selector}|attribute|${attribute}|${toScalar(
                    value
                  )}`,
                  {
                    name,
                    selector,
                    attribute,
                    value: toScalar(value),
                  }
                )
              }
            }
          }

          await updateYield()
        }
      }
    }
  }

  return technologies
}

function getCookies() {
  const cookies = {}

  if (!document.cookie) {
    return cookies
  }

  for (const cookie of document.cookie.split('; ')) {
    const [name, ...value] = cookie.split('=')

    cookies[name] = [value.join('=')]
  }

  return cookies
}

function getScriptSources() {
  return Array.from(document.scripts)
    .filter(({ src }) => src && !src.startsWith('data:text/javascript;'))
    .map(({ src }) => src)
}

function getMeta() {
  const meta = {}

  for (const node of document.querySelectorAll('meta')) {
    const key = node.getAttribute('name') || node.getAttribute('property')

    if (!key) {
      continue
    }

    const content = node.getAttribute('content')
    const normalizedKey = key.toLowerCase()

    meta[normalizedKey] = meta[normalizedKey] || []
    meta[normalizedKey].push(content)
  }

  return meta
}

async function getHeavySignals() {
  await yieldToMain()

  // Text
  const text = collectVisibleText(MAX_TEXT_LENGTH)

  // CSS rules
  const css = []

  try {
    for (const sheet of Array.from(document.styleSheets)) {
      for (const rules of Array.from(sheet.cssRules)) {
        css.push(rules.cssText)

        if (css.length >= 3000) {
          break
        }
      }

      if (css.length >= 3000) {
        break
      }
    }
  } catch (error) {
    // Continue
  }

  await yieldToMain()

  const scripts = []
  let totalScriptChars = 0

  for (const node of Array.from(document.scripts)) {
    const script = node.textContent

    if (!script) {
      continue
    }

    const remainingChars = MAX_INLINE_SCRIPT_CHARS - totalScriptChars

    if (remainingChars <= 0 || scripts.length >= MAX_INLINE_SCRIPT_COUNT) {
      break
    }

    scripts.push(script.slice(0, remainingChars))
    totalScriptChars += Math.min(script.length, remainingChars)
  }

  return {
    text,
    css: css.join('\n'),
    scripts,
  }
}

const Content = {
  cache: {},
  language: '',

  analyzedRequires: [],

  error(error) {
    return Content.driver('error', error)
  },

  /**
   * Initialise content script
   */
  async init() {
    const url = location.href

    if (await Content.driver('isDisabledDomain', url)) {
      return
    }

    await new Promise((resolve) => setTimeout(resolve, 1000))

    try {
      Content.language = normalizeLanguageTag(
        document.documentElement.getAttribute('lang') ||
          document.documentElement.getAttribute('xml:lang')
      )

      if (!Content.language) {
        Content.language = await detectLanguageFromVisibleText()
      }

      Content.cache = {
        cookies: getCookies(),
        meta: getMeta(),
        scriptSrc: getScriptSources(),
      }

      // Detect Google Ads
      if (/^(www\.)?google(\.[a-z]{2,3}){1,2}$/.test(location.hostname)) {
        const ads = document.querySelectorAll(
          '#tads [data-text-ad] a[data-pcu]'
        )

        for (const ad of ads) {
          Content.driver('detectTechnology', [ad.href, 'Google Ads'])
        }
      }

      // Detect Microsoft Ads
      if (/^(www\.)?bing\.com$/.test(location.hostname)) {
        const ads = document.querySelectorAll('.b_ad .b_adurl cite')

        for (const ad of ads) {
          const url = ad.textContent.split(' ')[0].trim()

          Content.driver('detectTechnology', [
            url.startsWith('http') ? url : `http://${url}`,
            'Microsoft Advertising',
          ])
        }
      }

      // Detect Facebook Ads
      if (/^(www\.)?facebook\.com$/.test(location.hostname)) {
        const ads = document.querySelectorAll('a[aria-label="Advertiser"]')

        for (const ad of ads) {
          const urls = [
            ...new Set([
              `https://${decodeURIComponent(
                ad.href.split(/^.+\?u=https%3A%2F%2F/).pop()
              )
                .split('/')
                .shift()}`,

              // eslint-disable-next-line unicorn/prefer-text-content
              `https://${ad.innerText.split('\n').pop()}`,
            ]),
          ]

          urls.forEach((url) =>
            Content.driver('detectTechnology', [url, 'Facebook Ads'])
          )
        }
      }

      await Content.driver('onContentLoad', [
        url,
        Content.cache,
        Content.language,
      ])

      const technologies = await Content.driver('getTechnologies')

      await Content.onGetTechnologies(technologies)

      const heavySignals = await getHeavySignals()

      Object.assign(Content.cache, heavySignals)

      Content.analyzedRequires = []

      if (hasHeavySignals(heavySignals)) {
        await Content.driver('onContentLoad', [
          url,
          heavySignals,
          Content.language,
          undefined,
          undefined,
          {
            includeUrl: false,
            skipCookies: true,
          },
        ])
      }

      // Delayed second pass to capture async JS
      await new Promise((resolve) => setTimeout(resolve, 5000))

      const js = await getJs(technologies)

      await Content.driver('analyzeJs', [url, js])
    } catch (error) {
      Content.driver('error', error)
    }
  },

  /**
   * Enable scripts to call Driver functions through messaging
   * @param {Object} message
   * @param {Object} sender
   * @param {Function} callback
   */
  onMessage({ source, func, args }, sender, callback) {
    if (!func) {
      return
    }

    Content.driver('log', { source, func, args })

    if (!Content[func]) {
      Content.error(new Error(`Method does not exist: Content.${func}`))

      return
    }

    Promise.resolve(Content[func].call(Content[func], ...(args || [])))
      .then(callback)
      .catch((error) => {
        Content.error(error)

        if (typeof callback === 'function') {
          callback()
        }
      })

    return !!callback
  },

  driver(func, args) {
    return new Promise((resolve) => {
      chrome.runtime.sendMessage(
        {
          source: 'content.js',
          func,
          args:
            args instanceof Error
              ? [args.toString()]
              : args
              ? Array.isArray(args)
                ? args
                : [args]
              : [],
        },
        (response) => {
          if (!chrome.runtime.lastError) {
            resolve(response)

            return
          }

          if (func !== 'error') {
            Content.error(
              new Error(
                `${
                  chrome.runtime.lastError.message
                }: Driver.${func}(${JSON.stringify(args)})`
              )
            )
          }

          resolve()
        }
      )
    })
  },

  async analyzeRequires(url, requires) {
    await Promise.all(
      (Array.isArray(requires) ? requires : [])
        .filter(Boolean)
        .map(async ({ name, categoryId, technologies }) => {
          const id = categoryId
            ? `category:${categoryId}`
            : `technology:${name}`
          const requiredTechnologyNames =
            getRequiredTechnologyNames(technologies)

          if (
            !Content.analyzedRequires.includes(id) &&
            Object.keys(Content.cache).length
          ) {
            Content.analyzedRequires.push(id)

            await Promise.all([
              Content.onGetTechnologies(
                technologies,
                name,
                categoryId,
                requiredTechnologyNames
              ),
              Content.driver('onContentLoad', [
                url,
                Content.cache,
                Content.language,
                name,
                categoryId,
                {
                  requiredTechnologyNames,
                },
              ]),
            ])
          }
        })
    )
  },

  async refreshMetadata() {
    const url = location.href

    Content.cache = {
      ...Content.cache,
      cookies: getCookies(),
      meta: getMeta(),
      scriptSrc: getScriptSources(),
    }

    await Content.driver('onContentLoad', [
      url,
      {
        cookies: Content.cache.cookies,
        meta: Content.cache.meta,
        scriptSrc: Content.cache.scriptSrc,
      },
      Content.language,
    ])
  },

  /**
   * Callback for getTechnologies
   * @param {Array} technologies
   */
  async onGetTechnologies(
    technologies = [],
    requires,
    categoryRequires,
    requiredTechnologyNames
  ) {
    const url = location.href
    const validTechnologies = (
      Array.isArray(technologies) ? technologies : []
    ).filter(Boolean)

    const js = await getJs(validTechnologies)
    const dom = await getDom(validTechnologies)

    await Promise.all([
      Content.driver('analyzeJs', [
        url,
        js,
        requires,
        categoryRequires,
        requiredTechnologyNames,
      ]),
      Content.driver('analyzeDom', [
        url,
        dom,
        requires,
        categoryRequires,
        requiredTechnologyNames,
      ]),
    ])
  },
}

// Enable messaging between scripts
chrome.runtime.onMessage.addListener(Content.onMessage)

if (/complete|interactive|loaded/.test(document.readyState)) {
  Content.init()
} else {
  document.addEventListener('DOMContentLoaded', Content.init)
}
