'use strict'
/* eslint-env browser */
/* globals browser, chrome, Wappalyzer, Utils */

const {
  setTechnologies,
  setCategories,
  analyze,
  analyzeManyToMany,
  resolve,
  getTechnology,
  getTechnologiesByTypes,
} = Wappalyzer
const {
  agent,
  promisify,
  getOption,
  setOption,
  open,
  close,
  globEscape,
  normalizeError,
  isMissingTabError,
} = Utils

const expiry = 1000 * 60 * 60 * 48

const maxHostnames = 100
const maxPingUrls = 25
const maxPingTechnologies = 25
const maxExternalScriptChars = 100000
const persistDebounce = 1000
const tabAwareMethods = new Set([
  'analyzeDom',
  'analyzeJs',
  'detectTechnology',
  'onContentLoad',
])

const hostnameIgnoreList =
  /\b((local|dev(elop(ment)?)?|sandbox|stag(e|ing)?|preprod|production|preview|internal|test(ing)?|[^a-z]demo(shop)?|cache)[.-]|dev\d|localhost|((wappalyzer|google|bing|baidu|microsoft|duckduckgo|facebook|adobe|alibaba|aliexpress|instagram|twitter|x|reddit|yahoo|wikipedia|amazon|amazonaws|youtube|stackoverflow|github|stackexchange|w3schools|twitch)\.)|(brave|live|office|herokuapp|shopifyapps|shopifypreview)\.com|bit\.ly|business\.site|linktr\.ee|\.local|\.test|\.netlify\.app|ngrok|web\.archive\.org|zoom\.us|^([0-9.]+|[\d.]+)$|^([a-f0-9:]+:+)+[a-f0-9]+$)/
const transientHostnameIgnoreList =
  /\b((local|dev(elop(ment)?)?|sandbox|stag(e|ing)?|preprod|production|preview|internal|test(ing)?|[^a-z]demo(shop)?|cache)[.-]|dev\d|localhost|(herokuapp|shopifypreview)\.com|\.local|\.test|\.netlify\.app|ngrok|^([0-9.]+|[\d.]+)$|^([a-f0-9:]+:+)+[a-f0-9]+$)/

const xhrDebounce = []

let xhrAnalyzed = {}

let initDone

const initPromise = new Promise((resolve) => {
  initDone = resolve
})

function createDriverCache(cache = {}) {
  return {
    hostnames: cache.hostnames || {},
    robots: cache.robots || {},
    tabResults: cache.tabResults || {},
    tabRequests: cache.tabRequests || {},
    tabScripts: cache.tabScripts || Object.create(null),
    tabActions: cache.tabActions || Object.create(null),
  }
}

function mergeCacheEntries(baseEntries = {}, runtimeEntries = {}) {
  return Object.fromEntries(
    Array.from(
      new Set([...Object.keys(baseEntries), ...Object.keys(runtimeEntries)])
    ).map((key) => [
      key,
      {
        ...(baseEntries[key] || {}),
        ...(runtimeEntries[key] || {}),
      },
    ])
  )
}

function getRequiredTechnologyNames(requiredTechnologyNames = []) {
  return [
    ...new Set(
      Array.isArray(requiredTechnologyNames) ? requiredTechnologyNames : []
    ),
  ].filter(
    (requiredTechnologyName) => typeof requiredTechnologyName === 'string'
  )
}

function getRequiredTechnologies(
  name,
  categoryId,
  requiredTechnologyNames = []
) {
  const normalizedRequiredTechnologyNames = getRequiredTechnologyNames(
    requiredTechnologyNames
  )

  if (normalizedRequiredTechnologyNames.length) {
    return normalizedRequiredTechnologyNames
      .map((requiredTechnologyName) =>
        Wappalyzer.getTechnology(requiredTechnologyName)
      )
      .filter(Boolean)
  }

  if (typeof name === 'string' && name) {
    const technologies = Wappalyzer.requires.find(
      (requirement) => requirement?.name === name
    )?.technologies

    // Service worker restarts can race with content-script follow-up passes.
    return technologies || []
  }

  const hasCategoryRequirement =
    typeof categoryId !== 'undefined' &&
    categoryId !== null &&
    `${categoryId}` !== ''
  const normalizedCategoryId = parseInt(categoryId, 10)

  if (hasCategoryRequirement && !Number.isNaN(normalizedCategoryId)) {
    const technologies = Wappalyzer.categoryRequires.find(
      (requirement) => requirement?.categoryId === normalizedCategoryId
    )?.technologies

    // Service worker restarts can race with content-script follow-up passes.
    return technologies || []
  }

  if (hasCategoryRequirement) {
    return []
  }

  return undefined
}

function isSimilarUrl(a, b) {
  const normalise = (url) => String(url || '').replace(/(\/|\/?#.+)$/, '')

  return normalise(a) === normalise(b)
}

function normalizeUrl(url) {
  return `${url || ''}`.split('#')[0]
}

function normalizeIpAddress(ip) {
  return `${ip || ''}`
    .trim()
    .toLowerCase()
    .replace(/^\[|\]$/g, '')
}

function normalizeStatusCode(statusCode) {
  const normalized = parseInt(statusCode, 10)

  return normalized > 0 ? normalized : 0
}

function isErrorStatusCode(statusCode) {
  const normalized = normalizeStatusCode(statusCode)

  return normalized >= 400 && normalized < 600
}

function getIpv4Octets(ip) {
  if (!/^\d{1,3}(?:\.\d{1,3}){3}$/.test(ip)) {
    return null
  }

  const octets = ip.split('.').map(Number)

  if (octets.some((octet) => octet > 255)) {
    return null
  }

  return octets
}

function isPrivateIpAddress(ip) {
  const normalized = normalizeIpAddress(ip)

  if (!normalized) {
    return false
  }

  const ipv4Mapped = normalized.match(/^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/)

  if (ipv4Mapped) {
    return isPrivateIpAddress(ipv4Mapped[1])
  }

  const octets = getIpv4Octets(normalized)

  if (octets) {
    const [first, second] = octets

    return (
      first === 10 ||
      first === 127 ||
      (first === 169 && second === 254) ||
      (first === 172 && second >= 16 && second <= 31) ||
      (first === 192 && second === 168)
    )
  }

  return (
    normalized === '::1' ||
    /^f[cd][0-9a-f:]*$/i.test(normalized) ||
    /^fe[89ab][0-9a-f:]*$/i.test(normalized)
  )
}

function isSameOriginUrl(a, b) {
  try {
    return new URL(a).origin === new URL(b).origin
  } catch (error) {
    return false
  }
}

function isTopFrameId(frameId) {
  return typeof frameId !== 'number' || frameId === 0
}

function hasValues(value) {
  if (Array.isArray(value)) {
    return value.length > 0
  }

  if (value && value.constructor === Object) {
    return Object.keys(value).length > 0
  }

  return !!value
}

function getItemTypes(items) {
  return Object.keys(items).filter((type) => hasValues(items[type]))
}

async function fetchTextSnippet(url, maxChars = maxExternalScriptChars) {
  const response = await fetch(url)

  if (!response.ok) {
    throw new Error(`Failed to fetch script: ${response.status} ${url}`)
  }

  if (!response.body || !response.body.getReader) {
    return (await response.text()).slice(0, maxChars)
  }

  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let text = ''

  try {
    while (text.length < maxChars) {
      const { done, value } = await reader.read()

      if (done) {
        break
      }

      text += decoder.decode(value, { stream: true })
    }

    text += decoder.decode()
  } finally {
    reader.cancel().catch(() => {})
  }

  return text.slice(0, maxChars)
}

const optionCache = new Map()

async function getCachedOption(name, defaultValue = null) {
  if (optionCache.has(name)) {
    return optionCache.get(name)
  }

  const value = await getOption(name, defaultValue)

  optionCache.set(name, value)

  return value
}

function setCachedOption(name, value) {
  optionCache.set(name, value)

  return setOption(name, value)
}

function removeCachedOption(name) {
  optionCache.delete(name)

  return promisify(chrome.storage.local, 'remove', name)
}

function getDefaultActionIconPath() {
  const manifest = chrome.runtime.getManifest()
  const defaultIcon =
    manifest.action?.default_icon ||
    manifest.browser_action?.default_icon ||
    manifest.icons

  if (typeof defaultIcon === 'string') {
    return chrome.runtime.getURL(defaultIcon)
  }

  if (defaultIcon && defaultIcon.constructor === Object) {
    return Object.fromEntries(
      Object.entries(defaultIcon).map(([size, path]) => [
        size,
        chrome.runtime.getURL(path),
      ])
    )
  }

  return chrome.runtime.getURL('images/icon_16.png')
}

function getActionApi() {
  return (
    (typeof browser !== 'undefined' &&
      (browser.action || browser.browserAction)) ||
    chrome.action ||
    chrome.browserAction
  )
}

function callAction(method, ...args) {
  const actionApi = getActionApi()

  if (!actionApi || typeof actionApi[method] !== 'function') {
    return Promise.resolve(undefined)
  }

  if (
    typeof browser !== 'undefined' &&
    (browser.action?.[method] || browser.browserAction?.[method])
  ) {
    return actionApi[method](...args)
  }

  return promisify(actionApi, method, ...args)
}

function getActionPathKey(path) {
  return typeof path === 'string' ? path : JSON.stringify(path)
}

function isExpectedScriptFetchError(error) {
  const message = normalizeError(error).message

  return (
    /^Failed to fetch script: \d{3}\b/.test(message) ||
    /(?:^|:\s)Failed to fetch$/.test(message)
  )
}

async function getTabsByUrl(url) {
  if (!url) {
    return []
  }

  let tabs = []

  try {
    tabs = await promisify(chrome.tabs, 'query', {
      url: globEscape(url),
    })
  } catch (error) {
    // Continue
  }

  if (tabs.length) {
    return tabs
  }

  try {
    return (await promisify(chrome.tabs, 'query', {})).filter(
      ({ url: tabUrl }) =>
        tabUrl &&
        isSimilarUrl(`${tabUrl}`.split('#')[0], `${url}`.split('#')[0])
    )
  } catch (error) {
    return []
  }
}

const sessionFallback = Object.create(null)

async function getSessionOption(name, defaultValue = null) {
  if (Object.prototype.hasOwnProperty.call(sessionFallback, name)) {
    return sessionFallback[name]
  }

  if (chrome.storage?.session) {
    try {
      const option = await promisify(chrome.storage.session, 'get', name)

      if (option[name] !== undefined) {
        sessionFallback[name] = option[name]

        return option[name]
      }
    } catch (error) {
      // Continue with in-memory fallback.
    }
  }

  return defaultValue
}

async function setSessionOption(name, value) {
  sessionFallback[name] = value

  if (!chrome.storage?.session) {
    return
  }

  try {
    await promisify(chrome.storage.session, 'set', {
      [name]: value,
    })
  } catch (error) {
    // Continue with in-memory fallback.
  }
}

async function removeSessionOption(name) {
  delete sessionFallback[name]

  if (!chrome.storage?.session) {
    return
  }

  try {
    await promisify(chrome.storage.session, 'remove', name)
  } catch (error) {
    // Continue with in-memory fallback.
  }
}

async function getCachedHostnames() {
  const sessionHostnames = await getSessionOption('hostnames', null)

  if (sessionHostnames && typeof sessionHostnames === 'object') {
    return sessionHostnames
  }

  const localHostnames = await getCachedOption('hostnames', null)

  if (localHostnames && typeof localHostnames === 'object') {
    await setSessionOption('hostnames', localHostnames)
  }

  if (localHostnames !== null) {
    await removeCachedOption('hostnames').catch(() => {})
  }

  return localHostnames || {}
}

function setCachedHostnames(hostnames) {
  return setSessionOption('hostnames', hostnames)
}

async function removeCachedHostnames() {
  await Promise.all([
    removeSessionOption('hostnames'),
    removeCachedOption('hostnames').catch(() => {}),
  ])
}

function deserializeRegex(regex) {
  const source = regex?.source || (typeof regex === 'string' ? regex : '')

  try {
    return new RegExp(source, 'i')
  } catch {
    return new RegExp('', 'i')
  }
}

function deserializeDetections(detections = []) {
  return detections
    .map(
      ({
        technology,
        pattern: { regex, confidence, value } = {},
        version,
        rootPath,
        lastUrl,
      }) => {
        const name =
          typeof technology === 'string' ? technology : technology?.name

        return {
          technology: getTechnology(name, true),
          pattern: {
            regex: deserializeRegex(regex),
            confidence,
            ...(typeof value !== 'undefined' ? { value } : {}),
          },
          version,
          rootPath,
          lastUrl,
        }
      }
    )
    .filter(({ technology }) => technology)
}

function serializeDetections(detections = []) {
  return detections
    .filter(({ technology }) => technology)
    .map(
      ({
        technology: { name: technology },
        pattern: { regex, confidence, value } = {},
        version,
        rootPath,
        lastUrl,
      }) => ({
        technology,
        pattern: {
          regex: regex?.source || '',
          confidence,
          ...(typeof value !== 'undefined' ? { value } : {}),
        },
        version,
        rootPath,
        lastUrl,
      })
    )
}

function serializeHostnamesCache(hostnameCache = {}) {
  const hostnames = {}

  for (const hostname of Object.keys(hostnameCache)) {
    const cache = { ...hostnameCache[hostname] }

    delete cache.https

    hostnames[hostname] = {
      ...cache,
      detections: serializeDetections(cache.detections),
    }
  }

  return hostnames
}

function mergeDetections(existingDetections = [], detections = [], url) {
  const { pathname } = new URL(url)
  const validDetections = detections.filter(({ technology }) => technology)

  const mergedDetections = existingDetections
    .concat(validDetections)
    .filter(({ technology }) => technology)
    .filter(
      (
        {
          technology: { name },
          pattern: { regex, value },
          confidence,
          version,
        },
        index,
        mergedDetections
      ) =>
        mergedDetections.findIndex(
          ({
            technology: { name: _name },
            pattern: { regex: _regex, value: _value },
            confidence: _confidence,
            version: _version,
          }) =>
            name === _name &&
            version === _version &&
            confidence === _confidence &&
            value === _value &&
            (!regex || regex.toString() === _regex.toString())
        ) === index
    )
    .map((detection) => {
      if (
        validDetections.find(
          ({ technology: { slug } }) => slug === detection.technology.slug
        )
      ) {
        detection.lastUrl = url
      }

      return detection
    })

  validDetections.forEach(({ technology: { name } }) => {
    const detection = mergedDetections.find(
      ({ technology: { name: _name } }) => name === _name
    )

    if (detection) {
      detection.rootPath = detection.rootPath || pathname === '/'
    }
  })

  return mergedDetections
}

function normalizeTechnologyHits(
  technologyHits = Object.create(null),
  detections = [],
  fallbackHits = 0
) {
  const normalizedHits = Object.entries(technologyHits || {}).reduce(
    (hits, [name, value]) => {
      const total = parseInt(value, 10) || 0

      if (name && total > 0) {
        hits[name] = total
      }

      return hits
    },
    Object.create(null)
  )
  const normalizedFallbackHits = parseInt(fallbackHits, 10) || 0

  if (Object.keys(normalizedHits).length || !normalizedFallbackHits) {
    return normalizedHits
  }

  resolve(detections).forEach(({ name, confidence }) => {
    if (name && confidence === 100) {
      normalizedHits[name] = normalizedFallbackHits
    }
  })

  return normalizedHits
}

function incrementTechnologyHits(
  technologyHits = Object.create(null),
  detections = []
) {
  const nextTechnologyHits = normalizeTechnologyHits(technologyHits)

  resolve(detections).forEach(({ name, confidence }) => {
    if (name && confidence === 100) {
      nextTechnologyHits[name] = (nextTechnologyHits[name] || 0) + 1
    }
  })

  return nextTechnologyHits
}

function sortTechnologyEntriesByHits(
  [nameA, technologyA],
  [nameB, technologyB]
) {
  return (
    (parseInt(technologyB?.hits, 10) || 0) -
      (parseInt(technologyA?.hits, 10) || 0) || nameA.localeCompare(nameB)
  )
}

function limitPingTechnologies(technologies = Object.create(null)) {
  return Object.fromEntries(
    Object.entries(technologies)
      .sort(sortTechnologyEntriesByHits)
      .slice(0, maxPingTechnologies)
  )
}

function getAverageTechnologyHits(technologies = Object.create(null)) {
  const technologyEntries = Object.values(technologies)

  if (!technologyEntries.length) {
    return 0
  }

  return (
    technologyEntries.reduce(
      (total, { hits }) => total + (parseInt(hits, 10) || 0),
      0
    ) / technologyEntries.length
  )
}

function sortPingCandidatesByAverageHits(a, b) {
  return (
    b.avgTechnologyHits - a.avgTechnologyHits ||
    b.hits - a.hits ||
    b.dateTime - a.dateTime ||
    a.hostname.localeCompare(b.hostname)
  )
}

chrome.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== 'local') {
    return
  }

  Object.keys(changes).forEach((name) => {
    if ('newValue' in changes[name]) {
      optionCache.set(name, changes[name].newValue)
    } else {
      optionCache.delete(name)
    }
  })
})

const Driver = {
  cache: createDriverCache(),
  persistTimer: null,
  pingPromise: null,

  /**
   * Initialise driver
   */
  async init() {
    await Driver.loadTechnologies()

    const runtimeCache = createDriverCache(Driver.cache)
    const hostnameCache = await getCachedHostnames()
    const hostnames = {}
    const robots = await getCachedOption('robots', {})
    const transientTabResults = await getSessionOption('tabResults', {})
    const transientTabRequests = await getSessionOption('tabRequests', {})
    let removedIgnoredHostnames = false

    for (const hostname of Object.keys(hostnameCache)) {
      if (transientHostnameIgnoreList.test(hostname)) {
        removedIgnoredHostnames = true

        continue
      }

      const cache = { ...hostnameCache[hostname] }
      const detections = deserializeDetections(cache.detections)

      delete cache.https

      hostnames[hostname] = {
        ...cache,
        detections,
        technologyHits: normalizeTechnologyHits(
          cache.technologyHits,
          detections,
          cache.hits
        ),
      }
    }

    Driver.cache = createDriverCache({
      hostnames: mergeCacheEntries(hostnames, runtimeCache.hostnames),
      robots: {
        ...robots,
        ...runtimeCache.robots,
      },
      tabResults: mergeCacheEntries(
        Object.fromEntries(
          Object.entries(transientTabResults).map(([tabId, result]) => [
            tabId,
            {
              ...result,
              detections: deserializeDetections(result.detections),
            },
          ])
        ),
        runtimeCache.tabResults
      ),
      tabRequests: mergeCacheEntries(
        Object.fromEntries(
          Object.entries(transientTabRequests).map(([tabId, request]) => [
            tabId,
            {
              ...request,
              ip: normalizeIpAddress(request.ip),
              statusCode: normalizeStatusCode(request.statusCode),
              isPrivateIp: !!request.isPrivateIp,
            },
          ])
        ),
        runtimeCache.tabRequests
      ),
      tabScripts: runtimeCache.tabScripts,
      tabActions: runtimeCache.tabActions,
    })

    if (removedIgnoredHostnames) {
      await setCachedHostnames(serializeHostnamesCache(hostnames))
    }

    const { version } = chrome.runtime.getManifest()
    const previous = await getCachedOption('version')
    const upgradeMessage = await getCachedOption('upgradeMessage', true)

    await setCachedOption('version', version)

    const current = await getCachedOption('version')

    if (!previous) {
      await Driver.clearCache()

      if (current) {
        open(
          'https://www.wappalyzer.com/installed/?utm_source=installed&utm_medium=extension&utm_campaign=wappalyzer'
        )

        const termsAccepted =
          agent === 'chrome' || (await getCachedOption('termsAccepted', false))

        if (!termsAccepted) {
          open(chrome.runtime.getURL('html/terms.html'))
        }
      }
    } else if (current && current !== previous && upgradeMessage) {
      open(
        `https://www.wappalyzer.com/upgraded/?utm_source=upgraded&utm_medium=extension&utm_campaign=wappalyzer`,
        false
      )
    }

    initDone()
  },

  closeCurrentTab(tabId) {
    close(tabId)
  },

  /**
   * Log debug messages to the console
   * @param {String} message
   * @param {String} source
   * @param {String} type
   */
  log(message, source = 'driver', type = 'log') {
    // eslint-disable-next-line no-console
    console[type](message)
  },

  /**
   * Log errors to the console
   * @param {String} error
   * @param {String} source
   */
  error(error, source = 'driver') {
    Driver.log(normalizeError(error), source, 'error')
  },

  getTechnologiesForItems(
    items,
    requires,
    categoryRequires,
    requiredTechnologyNames
  ) {
    return (
      getRequiredTechnologies(
        requires,
        categoryRequires,
        requiredTechnologyNames
      ) || getTechnologiesByTypes(getItemTypes(items))
    )
  },

  isPingFilteredUrl(url) {
    try {
      const { hostname } = new URL(url)

      return hostnameIgnoreList.test(hostname)
    } catch (error) {
      return false
    }
  },

  isTransientHostname(url) {
    try {
      const { hostname } = new URL(url)

      return transientHostnameIgnoreList.test(hostname)
    } catch (error) {
      return false
    }
  },

  getTabRequest(tabId, url, allowSameOrigin = false) {
    if (typeof tabId !== 'number') {
      return null
    }

    const tabRequest = Driver.cache.tabRequests?.[tabId]

    if (!tabRequest) {
      return null
    }

    if (
      !isSimilarUrl(url, tabRequest.url) &&
      !(allowSameOrigin && isSameOriginUrl(url, tabRequest.url))
    ) {
      return null
    }

    return tabRequest
  },

  isTransientUrl(url, tabId, allowSameOrigin = false) {
    if (Driver.isTransientHostname(url)) {
      return true
    }

    const tabRequest = Driver.getTabRequest(tabId, url, allowSameOrigin)

    return (
      !!tabRequest?.isPrivateIp || isErrorStatusCode(tabRequest?.statusCode)
    )
  },

  getTabResult(tabId, url, allowSameOrigin = false) {
    if (typeof tabId !== 'number') {
      return null
    }

    const tabResult = Driver.cache.tabResults?.[tabId]

    if (!tabResult) {
      return null
    }

    if (
      !isSimilarUrl(url, tabResult.url) &&
      !(allowSameOrigin && isSameOriginUrl(url, tabResult.url))
    ) {
      return null
    }

    return tabResult
  },

  async persistTabResults() {
    const tabResults = Object.fromEntries(
      Object.entries(Driver.cache.tabResults || {}).map(([tabId, result]) => [
        tabId,
        {
          ...result,
          detections: serializeDetections(result.detections),
        },
      ])
    )

    if (Object.keys(tabResults).length) {
      await setSessionOption('tabResults', tabResults)
    } else {
      await removeSessionOption('tabResults')
    }
  },

  async persistTabRequests() {
    const tabRequests = Object.fromEntries(
      Object.entries(Driver.cache.tabRequests || {}).map(([tabId, request]) => [
        tabId,
        request,
      ])
    )

    if (Object.keys(tabRequests).length) {
      await setSessionOption('tabRequests', tabRequests)
    } else {
      await removeSessionOption('tabRequests')
    }
  },

  async clearTabResult(tabId) {
    if (typeof tabId !== 'number') {
      return
    }

    if (!Driver.cache.tabResults[tabId] && !Driver.cache.tabScripts[tabId]) {
      return
    }

    delete Driver.cache.tabResults[tabId]
    delete Driver.cache.tabScripts[tabId]

    await Driver.persistTabResults()
  },

  clearTabActionState(tabId) {
    if (typeof tabId !== 'number' || !Driver.cache.tabActions?.[tabId]) {
      return
    }

    delete Driver.cache.tabActions[tabId]
  },

  async clearTabRequest(tabId) {
    if (typeof tabId !== 'number') {
      return
    }

    if (!Driver.cache.tabRequests[tabId]) {
      return
    }

    delete Driver.cache.tabRequests[tabId]

    await Driver.persistTabRequests()
  },

  getResolvedDetections(
    url,
    detections = [],
    showCached = true,
    { lastUrlOverride } = {}
  ) {
    return resolve(detections)
      .map((detection) => ({
        ...detection,
        ...(lastUrlOverride ? { lastUrl: lastUrlOverride } : {}),
      }))
      .filter(({ lastUrl }) => showCached || isSimilarUrl(url, lastUrl))
  },

  async getDetectionsForTab(tab) {
    const { id: tabId, url } = tab || {}

    if (!url || !/^https?:/i.test(url)) {
      return []
    }

    const showCached = await getCachedOption('showCached', true)
    const tabResult = Driver.getTabResult(tabId, url, true)
    const isTransientResult =
      !!tabResult?.transient || Driver.isTransientUrl(url, tabId, true)
    const currentTabResult = isTransientResult || !showCached ? tabResult : null

    if (currentTabResult) {
      return Driver.getResolvedDetections(
        url,
        currentTabResult.detections,
        showCached,
        {
          lastUrlOverride: url,
        }
      )
    }

    const { hostname } = new URL(url)
    const cache = Driver.cache.hostnames?.[hostname]

    return Driver.getResolvedDetections(
      url,
      cache ? cache.detections : [],
      showCached
    )
  },

  pruneHostnamesCache() {
    Driver.cache.hostnames = Object.fromEntries(
      Object.entries(Driver.cache.hostnames)
        .sort(([, a], [, b]) => (a.dateTime > b.dateTime ? -1 : 1))
        .filter(
          ([, cache], index) =>
            cache.dateTime > Date.now() - expiry && index < maxHostnames
        )
    )
  },

  async persistHostnames() {
    Driver.pruneHostnamesCache()

    await setCachedHostnames(serializeHostnamesCache(Driver.cache.hostnames))
  },

  scheduleCachePersist() {
    clearTimeout(Driver.persistTimer)

    Driver.persistTimer = setTimeout(() => {
      Driver.persistTimer = null
      Driver.persistHostnames().catch(Driver.error)
    }, persistDebounce)
  },

  getPingPayload() {
    const urls = Object.create(null)
    const candidates = []

    for (const hostname of Object.keys(Driver.cache.hostnames)) {
      // eslint-disable-next-line standard/computed-property-even-spacing
      const { language, detections, hits, dateTime, technologyHits } =
        Driver.cache.hostnames[hostname]
      const normalizedHits = parseInt(hits, 10) || 0
      const normalizedTechnologyHits = normalizeTechnologyHits(
        technologyHits,
        detections,
        normalizedHits
      )

      if (hostnameIgnoreList.test(hostname) || !normalizedHits) {
        continue
      }

      const technologies = limitPingTechnologies(
        resolve(detections).reduce(
          (technologies, { name, confidence, version, rootPath }) => {
            const technologyHits = normalizedTechnologyHits[name] || 0

            if (confidence === 100 && technologyHits > 0) {
              technologies[name] = {
                version,
                hits: technologyHits,
                rootPath,
              }
            }

            return technologies
          },
          Object.create(null)
        )
      )

      if (!Object.keys(technologies).length) {
        continue
      }

      candidates.push({
        hostname,
        hits: normalizedHits,
        dateTime: parseInt(dateTime, 10) || 0,
        avgTechnologyHits: getAverageTechnologyHits(technologies),
        technologies,
        language,
      })
    }

    const selectedCandidates =
      candidates.length > maxPingUrls
        ? candidates.sort(sortPingCandidatesByAverageHits).slice(0, maxPingUrls)
        : candidates

    const sentHostnames = []

    selectedCandidates.forEach(({ hostname, hits, technologies, language }) => {
      urls[`https://${hostname}`] = {
        technologies,
        meta: {
          language,
        },
      }
      sentHostnames.push({ hostname })
    })

    return {
      urls,
      sentHostnames,
    }
  },

  /**
   * Load technologies and categories into memory
   */
  async loadTechnologies() {
    try {
      const categories = await (
        await fetch(chrome.runtime.getURL('categories.json'))
      ).json()

      const technologies = {}
      const technologyData = await Promise.all(
        Array.from({ length: 27 }, async (_, index) => {
          const character = index ? String.fromCharCode(index + 96) : '_'

          return (
            await fetch(chrome.runtime.getURL(`technologies/${character}.json`))
          ).json()
        })
      )

      technologyData.forEach((data) => Object.assign(technologies, data))

      Object.keys(technologies).forEach((name) => {
        delete technologies[name].description
        delete technologies[name].cpe
        delete technologies[name].pricing
        delete technologies[name].website
      })

      setTechnologies(technologies)
      setCategories(categories)
    } catch (error) {
      Driver.error(error)
    }
  },

  /**
   * Get all categories
   */
  getCategories() {
    return Wappalyzer.categories
  },

  /**
   * Perform a HTTP POST request
   * @param {String} url
   * @param {String} body
   */
  post(url, body) {
    return fetch(url, {
      method: 'POST',
      body: JSON.stringify(body),
      headers: {
        'Content-Type': 'application/json',
      },
    })
  },

  /**
   * Wrapper for analyze
   */
  analyze(...args) {
    return analyze(...args)
  },

  /**
   * Analyse JavaScript variables
   * @param {String} url
   * @param {Array} js
   */
  analyzeJs(
    url,
    js,
    requires,
    categoryRequires,
    requiredTechnologyNames,
    tabId,
    frameId
  ) {
    const technologies =
      getRequiredTechnologies(
        requires,
        categoryRequires,
        requiredTechnologyNames
      ) || Wappalyzer.technologies
    const technologiesByName = Object.fromEntries(
      technologies
        .filter((technology) => technology?.name)
        .map((technology) => [technology.name, technology])
    )

    return Driver.onDetect(
      url,
      js
        .map(({ name, chain, value }) => {
          const technology = technologiesByName[name]

          return technology
            ? analyzeManyToMany(technology, 'js', { [chain]: [value] })
            : []
        })
        .flat(),
      undefined,
      false,
      tabId,
      frameId
    )
  },

  /**
   * Analyse DOM nodes
   * @param {String} url
   * @param {Array} dom
   */
  analyzeDom(
    url,
    dom,
    requires,
    categoryRequires,
    requiredTechnologyNames,
    tabId,
    frameId
  ) {
    const technologies =
      getRequiredTechnologies(
        requires,
        categoryRequires,
        requiredTechnologyNames
      ) || Wappalyzer.technologies
    const technologiesByName = Object.fromEntries(
      technologies
        .filter((technology) => technology?.name)
        .map((technology) => [technology.name, technology])
    )

    return Driver.onDetect(
      url,
      dom
        .map(
          (
            { name, selector, exists, text, property, attribute, value },
            index
          ) => {
            const technology = technologiesByName[name]

            if (!technology) {
              return []
            }

            if (typeof exists !== 'undefined') {
              return analyzeManyToMany(technology, 'dom.exists', {
                [selector]: [''],
              })
            }

            if (typeof text !== 'undefined') {
              return analyzeManyToMany(technology, 'dom.text', {
                [selector]: [text],
              })
            }

            if (typeof property !== 'undefined') {
              return analyzeManyToMany(
                technology,
                `dom.properties.${property}`,
                {
                  [selector]: [value],
                }
              )
            }

            if (typeof attribute !== 'undefined') {
              return analyzeManyToMany(
                technology,
                `dom.attributes.${attribute}`,
                {
                  [selector]: [value],
                }
              )
            }
          }
        )
        .flat(),
      undefined,
      false,
      tabId,
      frameId
    )
  },

  /**
   * Force a technology detection by URL and technology name
   * @param {String} url
   * @param {String} name
   */
  detectTechnology(url, name, tabId, frameId) {
    const technology = getTechnology(name)

    return Driver.onDetect(
      url,
      [{ technology, pattern: { regex: '', confidence: 100 }, version: '' }],
      undefined,
      false,
      tabId,
      frameId
    )
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

    if (func === 'closeCurrentTab') {
      args = [sender.tab.id]
    }

    if (func !== 'log') {
      Driver.log({ source, func, args })
    }

    if (!Driver[func]) {
      Driver.error(new Error(`Method does not exist: Driver.${func}`))

      return
    }

    if (tabAwareMethods.has(func) && sender?.tab?.id) {
      args = [...(args || []), sender.tab.id, sender.frameId]
    }

    // eslint-disable-next-line no-async-promise-executor
    new Promise(async (resolve) => {
      await initPromise

      resolve(Driver[func].call(Driver[func], ...(args || [])))
    })
      .then(callback)
      .catch((error) => {
        Driver.error(error)

        if (typeof callback === 'function') {
          callback()
        }
      })

    return !!callback
  },

  async content(url, func, args) {
    const [tab] = await getTabsByUrl(url)

    if (!tab) {
      return
    }

    if (tab.status !== 'complete') {
      throw new Error(`Tab ${tab.id} not ready for sendMessage: ${tab.status}`)
    }

    return new Promise((resolve, reject) => {
      chrome.tabs.sendMessage(
        tab.id,
        {
          source: 'driver.js',
          func,
          args: args ? (Array.isArray(args) ? args : [args]) : [],
        },
        (response) => {
          if (!chrome.runtime.lastError) {
            resolve(response)

            return
          }

          if (isMissingTabError(chrome.runtime.lastError)) {
            resolve()

            return
          }

          if (func !== 'error') {
            Driver.error(
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

  async onResponseStarted(request) {
    if (
      typeof request.tabId !== 'number' ||
      request.tabId < 0 ||
      !request.url
    ) {
      return
    }

    const url = normalizeUrl(request.url)
    const existingTabRequest = Driver.getTabRequest(request.tabId, url, true)
    const ip = normalizeIpAddress(request.ip || existingTabRequest?.ip)
    const statusCode = normalizeStatusCode(
      request.statusCode || existingTabRequest?.statusCode
    )

    Driver.cache.tabRequests[request.tabId] = {
      url,
      ip,
      statusCode,
      isPrivateIp: isPrivateIpAddress(ip),
      dateTime: Date.now(),
    }

    await Driver.persistTabRequests()
  },

  /**
   * Analyse response headers
   * @param {Object} request
   */
  async onWebRequestComplete(request) {
    if (request.responseHeaders) {
      if (await Driver.isDisabledDomain(request.url)) {
        return
      }

      const headers = {}

      try {
        await new Promise((resolve) => setTimeout(resolve, 500))

        const [tab] = await getTabsByUrl(request.url)

        if (tab) {
          request.responseHeaders.forEach((header) => {
            const name = header?.name?.toLowerCase()

            if (!name) {
              return
            }

            headers[name] = headers[name] || []

            headers[name].push(
              (header.value || header.binaryValue || '').toString()
            )
          })

          Driver.onDetect(
            request.url,
            analyze({ headers }, getTechnologiesByTypes(['headers'])),
            undefined,
            false,
            request.tabId
          ).catch(Driver.error)
        }
      } catch (error) {
        Driver.error(error)
      }
    }
  },

  /**
   * Analyse scripts
   * @param {Object} request
   */
  async onScriptRequestComplete(request) {
    if (!isTopFrameId(request.frameId)) {
      return
    }

    const initiatorUrl = request.initiator || request.documentUrl || request.url

    if (
      (await Driver.isDisabledDomain(initiatorUrl)) ||
      (await Driver.isDisabledDomain(request.url))
    ) {
      return
    }

    const { hostname } = new URL(initiatorUrl)
    let analyzedScripts

    if (Driver.isTransientUrl(initiatorUrl, request.tabId, true)) {
      analyzedScripts = Driver.cache.tabScripts[request.tabId] =
        Driver.cache.tabScripts[request.tabId] || []
    } else {
      if (!Driver.cache.hostnames[hostname]) {
        Driver.cache.hostnames[hostname] = {}
      }

      if (!Driver.cache.hostnames[hostname].analyzedScripts) {
        Driver.cache.hostnames[hostname].analyzedScripts = []
      }

      analyzedScripts = Driver.cache.hostnames[hostname].analyzedScripts
    }

    if (analyzedScripts.includes(request.url)) {
      return
    }

    if (analyzedScripts.length >= 25) {
      return
    }

    analyzedScripts.push(request.url)

    try {
      const scripts = await fetchTextSnippet(request.url)

      Driver.onDetect(
        initiatorUrl,
        analyze({ scripts }, getTechnologiesByTypes(['scripts'])),
        undefined,
        false,
        request.tabId,
        request.frameId
      ).catch(Driver.error)
    } catch (error) {
      // Many third-party CDNs reject extension-origin refetches; skip those.
      if (!isExpectedScriptFetchError(error)) {
        Driver.error(error)
      }
    }
  },

  /**
   * Analyse XHR request hostnames
   * @param {Object} request
   */
  async onXhrRequestComplete(request) {
    if (!isTopFrameId(request.frameId)) {
      return
    }

    if (await Driver.isDisabledDomain(request.url)) {
      return
    }

    let hostname
    let originHostname

    try {
      ;({ hostname } = new URL(request.url))
      ;({ hostname: originHostname } = new URL(request.originUrl))
    } catch (error) {
      return
    }

    if (!xhrDebounce.includes(hostname)) {
      xhrDebounce.push(hostname)

      setTimeout(() => {
        xhrDebounce.splice(xhrDebounce.indexOf(hostname), 1)

        xhrAnalyzed[originHostname] = xhrAnalyzed[originHostname] || []

        if (!xhrAnalyzed[originHostname].includes(hostname)) {
          xhrAnalyzed[originHostname].push(hostname)

          if (Object.keys(xhrAnalyzed).length > 500) {
            xhrAnalyzed = {}
          }

          Driver.onDetect(
            request.originUrl || request.initiator,
            analyze({ xhr: hostname }, getTechnologiesByTypes(['xhr'])),
            undefined,
            false,
            request.tabId,
            request.frameId
          ).catch(Driver.error)
        }
      }, 1000)
    }
  },

  /**
   * Process return values from content.js
   * @param {String} url
   * @param {Object} items
   * @param {String} language
   */
  async onContentLoad(
    url,
    items = {},
    language,
    requires,
    categoryRequires,
    options,
    tabId,
    frameId
  ) {
    try {
      if (!options?.skipCookies) {
        items.cookies = items.cookies || {}
        ;(
          await promisify(chrome.cookies, 'getAll', {
            url,
          })
        ).forEach(
          ({ name, value }) => (items.cookies[name.toLowerCase()] = [value])
        )

        // Change Google Analytics 4 cookie from _ga_XXXXXXXXXX to _ga_*
        Object.keys(items.cookies).forEach((name) => {
          if (/_ga_[A-Z0-9]+/.test(name)) {
            items.cookies['_ga_*'] = items.cookies[name]

            delete items.cookies[name]
          }
        })
      }

      const analysisItems =
        options?.includeUrl === false ? items : { url, ...items }

      const technologies = Driver.getTechnologiesForItems(
        analysisItems,
        requires,
        categoryRequires,
        options?.requiredTechnologyNames
      )

      await Driver.onDetect(
        url,
        analyze(analysisItems, technologies),
        language,
        true,
        tabId,
        frameId
      )
    } catch (error) {
      Driver.error(error)
    }
  },

  /**
   * Get all technologies
   */
  getTechnologies() {
    return Wappalyzer.technologies
  },

  /**
   * Check if Wappalyzer has been disabled for the domain
   */
  async isDisabledDomain(url) {
    try {
      const { hostname } = new URL(url)

      return (await getCachedOption('disabledDomains', [])).includes(hostname)
    } catch (error) {
      return false
    }
  },

  /**
   * Callback for detections
   * @param {String} url
   * @param {Array} detections
   * @param {String} language
   * @param {Boolean} incrementHits
   */
  async onDetect(
    url,
    detections = [],
    language,
    incrementHits = false,
    tabId,
    frameId
  ) {
    if (!url || !detections.length) {
      return
    }

    if (!isTopFrameId(frameId)) {
      return
    }

    url = normalizeUrl(url)

    const { hostname } = new URL(url)
    const isTransientResult =
      typeof tabId === 'number' && Driver.isTransientUrl(url, tabId, true)
    let cache

    if (typeof tabId === 'number') {
      const existingTabResult = Driver.getTabResult(tabId, url, true)

      Driver.cache.tabResults[tabId] = {
        url,
        detections: mergeDetections(
          existingTabResult?.detections,
          detections,
          url
        ),
        language: Driver.cache.tabResults[tabId]?.language || language,
        transient: isTransientResult,
        dateTime: Date.now(),
      }

      await Driver.persistTabResults()
    }

    if (isTransientResult) {
      cache = Driver.cache.tabResults[tabId]
    } else {
      const hostnameCache = Driver.cache.hostnames[hostname] || {}

      cache = Driver.cache.hostnames[hostname] = {
        ...hostnameCache,
        detections: mergeDetections(hostnameCache.detections, detections, url),
        technologyHits: incrementHits
          ? incrementTechnologyHits(hostnameCache.technologyHits, detections)
          : normalizeTechnologyHits(
              hostnameCache.technologyHits,
              hostnameCache.detections,
              hostnameCache.hits
            ),
        hits: incrementHits ? 0 : 1,
        analyzedScripts: hostnameCache.analyzedScripts || [],
        dateTime: Date.now(),
      }

      cache.hits += incrementHits ? 1 : 0
      cache.language = cache.language || language

      Driver.pruneHostnamesCache()
      Driver.scheduleCachePersist()
    }

    const resolved = resolve(cache.detections).map((detection) => detection)

    // Look for technologies that require other technologies to be present on the page
    const requires = [
      ...Wappalyzer.requires.filter(
        (requirement) =>
          requirement?.name &&
          resolved.some(({ name }) => name === requirement.name)
      ),
      ...Wappalyzer.categoryRequires.filter(
        (requirement) =>
          typeof requirement?.categoryId === 'number' &&
          resolved.some(({ categories = [] }) =>
            categories.some(
              (category) => category?.id === requirement.categoryId
            )
          )
      ),
    ]

    if (requires.length) {
      Driver.content(url, 'analyzeRequires', [url, requires]).catch(() => {})
    }
    Driver.setIcon(url, resolved, tabId).catch(Driver.error)

    if (!isTransientResult) {
      Driver.ping().catch(Driver.error)
    }

    Driver.log({
      hostname,
      transient: isTransientResult,
      technologies: resolved,
    })
  },

  /**
   * Update the extension icon
   * @param {String} url
   * @param {Object} technologies
   */
  async setIcon(url, technologies = [], tabId) {
    if (await Driver.isDisabledDomain(url)) {
      technologies = []
    }

    const dynamicIcon = await getCachedOption('dynamicIcon', false)
    const showCached = await getCachedOption('showCached', true)
    const badge = await getCachedOption('badge', true)

    let icon = 'default.svg'

    const _technologies = technologies.filter(
      ({ slug, lastUrl }) =>
        slug !== 'cart-functionality' &&
        (showCached || isSimilarUrl(url, lastUrl))
    )

    if (dynamicIcon) {
      const pinnedCategory = parseInt(
        await getCachedOption('pinnedCategory'),
        10
      )

      const pinned = _technologies.find(({ categories }) =>
        categories.some(({ id }) => id === pinnedCategory)
      )

      ;({ icon } = pinned || _technologies[0] || { icon })
    }

    if (!url) {
      return
    }

    let tabs = []
    const badgeText =
      badge && _technologies.length ? _technologies.length.toString() : ''
    const iconPath =
      icon === 'default.svg'
        ? getDefaultActionIconPath()
        : chrome.runtime.getURL(
            `../images/icons/${
              /\.svg$/i.test(icon)
                ? `converted/${icon.replace(/\.svg$/, '.png')}`
                : icon
            }`
          )
    const iconPathKey = getActionPathKey(iconPath)

    try {
      tabs =
        typeof tabId === 'number'
          ? [await promisify(chrome.tabs, 'get', tabId)]
          : await getTabsByUrl(url)
    } catch (error) {
      // Continue
    }

    await Promise.all(
      tabs.map(async ({ id: tabId }) => {
        const currentState = Driver.cache.tabActions[tabId]

        if (
          currentState?.badgeText === badgeText &&
          currentState?.iconPathKey === iconPathKey
        ) {
          return
        }

        await callAction('setBadgeText', {
          tabId,
          text: badgeText,
        })

        await callAction('setIcon', {
          tabId,
          path: iconPath,
        })

        Driver.cache.tabActions[tabId] = {
          badgeText,
          iconPathKey,
        }
      })
    )
  },

  /**
   * Get the detected technologies for the current tab
   */
  async getDetections() {
    const [tab] = await promisify(chrome.tabs, 'query', {
      active: true,
      currentWindow: true,
    })

    if (!tab) {
      Driver.error(new Error('getDetections: no active tab found'))

      return
    }

    const { url } = tab

    if (await Driver.isDisabledDomain(url)) {
      await Driver.setIcon(url, [], tab.id)

      return
    }

    const resolved = await Driver.getDetectionsForTab(tab)

    await Driver.setIcon(url, resolved, tab.id)

    return resolved
  },

  /**
   * Fetch the website's robots.txt rules
   * @param {String} hostname
   * @param {Boolean} secure
   */
  async getRobots(hostname, secure = false) {
    if (
      !(await getCachedOption('tracking', true)) ||
      hostnameIgnoreList.test(hostname)
    ) {
      return []
    }

    if (typeof Driver.cache.robots[hostname] !== 'undefined') {
      return Driver.cache.robots[hostname]
    }

    try {
      Driver.cache.robots[hostname] = await Promise.race([
        // eslint-disable-next-line no-async-promise-executor
        new Promise(async (resolve) => {
          const response = await fetch(
            `http${secure ? 's' : ''}://${hostname}/robots.txt`
          )

          if (!response.ok) {
            Driver.log(`getRobots: ${response.statusText} (${hostname})`)

            resolve('')
          }

          let agent

          resolve(
            (await response.text()).split('\n').reduce((disallows, line) => {
              let matches = /^User-agent:\s*(.+)$/i.exec(line.trim())

              if (matches) {
                agent = matches[1].toLowerCase()
              } else if (agent === '*' || agent === 'wappalyzer') {
                matches = /^Disallow:\s*(.+)$/i.exec(line.trim())

                if (matches) {
                  disallows.push(matches[1])
                }
              }

              return disallows
            }, [])
          )
        }),
        new Promise((resolve) => setTimeout(() => resolve(''), 5000)),
      ])

      Driver.cache.robots = Object.keys(Driver.cache.robots)
        .slice(-50)
        .reduce(
          (cache, hostname) => ({
            ...cache,
            [hostname]: Driver.cache.robots[hostname],
          }),
          {}
        )

      await setCachedOption('robots', Driver.cache.robots)

      return Driver.cache.robots[hostname]
    } catch (error) {
      Driver.error(error)
    }
  },

  /**
   * Check if the website allows indexing of a URL
   * @param {String} href
   */
  async checkRobots(href) {
    const url = new URL(href)

    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      throw new Error('Invalid protocol')
    }

    const robots = await Driver.getRobots(
      url.hostname,
      url.protocol === 'https:'
    )

    if (robots.some((disallowed) => url.pathname.indexOf(disallowed) === 0)) {
      throw new Error('Disallowed')
    }
  },

  /**
   * Clear caches
   */
  async clearCache() {
    clearTimeout(Driver.persistTimer)
    Driver.persistTimer = null
    Driver.cache.hostnames = {}
    Driver.cache.tabResults = {}
    Driver.cache.tabRequests = {}
    Driver.cache.tabScripts = Object.create(null)
    Driver.cache.tabActions = Object.create(null)

    xhrAnalyzed = {}

    await removeCachedHostnames()
    await removeSessionOption('tabResults')
    await removeSessionOption('tabRequests')
  },

  /**
   * Anonymously send identified technologies to wappalyzer.com
   * This function can be disabled in the extension settings
   */
  ping() {
    if (Driver.pingPromise) {
      return Driver.pingPromise
    }

    Driver.pingPromise = (async () => {
      const tracking = await getCachedOption('tracking', true)
      const termsAccepted =
        agent === 'chrome' || (await getCachedOption('termsAccepted', false))

      if (!(tracking && termsAccepted)) {
        return
      }

      const { urls, sentHostnames } = Driver.getPingPayload()
      const count = sentHostnames.length
      const lastPing = await getCachedOption('lastPing', 0)

      if (
        !count ||
        !(
          (count >= 25 && lastPing < Date.now() - 1000 * 60 * 60) ||
          (count >= 5 && lastPing < Date.now() - expiry)
        )
      ) {
        return
      }

      sentHostnames.forEach(({ hostname }) => {
        if (!Driver.cache.hostnames[hostname]) {
          return
        }

        const cache = Driver.cache.hostnames[hostname]
        cache.technologyHits = Object.create(null)
        cache.hits = 0
      })

      // Prefer dropping already-selected hits over resending them if the
      // service worker or network path dies mid-request.
      await Driver.persistHostnames()

      await Driver.post('https://ping.wappalyzer.com/v2/', {
        version: chrome.runtime.getManifest().version,
        urls,
      })

      const now = Date.now()

      await Promise.all([
        setCachedOption('lastPing', now),
        Driver.persistHostnames(),
      ])
    })().finally(() => {
      Driver.pingPromise = null
    })

    return Driver.pingPromise
  },
}

chrome.action.setBadgeBackgroundColor({ color: '#6B39BD' }, () => {})

chrome.webRequest.onResponseStarted.addListener(
  (request) => {
    Driver.onResponseStarted(request).catch(Driver.error)
  },
  { urls: ['http://*/*', 'https://*/*'], types: ['main_frame'] }
)

chrome.webRequest.onCompleted.addListener(
  Driver.onWebRequestComplete,
  { urls: ['http://*/*', 'https://*/*'], types: ['main_frame'] },
  ['responseHeaders']
)

chrome.webRequest.onCompleted.addListener(Driver.onScriptRequestComplete, {
  urls: ['http://*/*', 'https://*/*'],
  types: ['script'],
})

chrome.webRequest.onCompleted.addListener(Driver.onXhrRequestComplete, {
  urls: ['http://*/*', 'https://*/*'],
  types: ['xmlhttprequest'],
})

chrome.tabs.onUpdated.addListener(async (id, { status, url }) => {
  try {
    if (status === 'loading') {
      await Driver.clearTabResult(id)
    }

    if (url && !/^https?:/i.test(url)) {
      await Driver.clearTabResult(id)
      await Driver.clearTabRequest(id)

      return
    }

    if (url) {
      const cachedTabResult = Driver.cache.tabResults?.[id]

      if (cachedTabResult) {
        if (
          !isSimilarUrl(url, cachedTabResult.url) &&
          !isSameOriginUrl(url, cachedTabResult.url)
        ) {
          await Driver.clearTabResult(id)
        }
      }
    }

    if (status === 'complete') {
      ;({ url } = await promisify(chrome.tabs, 'get', id))
    }

    if (!url || !/^https?:/i.test(url)) {
      return
    }

    if (status === 'complete') {
      await Driver.content(url, 'refreshMetadata').catch((error) => {
        if (!isMissingTabError(error)) {
          Driver.error(error)
        }
      })
    }

    const resolved = await Driver.getDetectionsForTab({ id, url })

    await Driver.setIcon(url, resolved, id)
  } catch (error) {
    if (!isMissingTabError(error)) {
      Driver.error(error)
    }
  }
})

chrome.tabs.onRemoved.addListener((tabId) => {
  Driver.clearTabResult(tabId).catch(Driver.error)
  Driver.clearTabRequest(tabId).catch(Driver.error)
  Driver.clearTabActionState(tabId)
})

// Enable messaging between scripts
chrome.runtime.onMessage.addListener(Driver.onMessage)

Driver.init()
