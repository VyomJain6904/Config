'use strict'
/* eslint-env browser */
/* globals chrome */

function getErrorMessage(error) {
  if (error instanceof Error) {
    return error.message || error.toString()
  }

  if (error && typeof error.message === 'string' && error.message) {
    return error.message
  }

  if (typeof error === 'string') {
    return error
  }

  try {
    const serialized = JSON.stringify(error)

    if (serialized && serialized !== '{}') {
      return serialized
    }
  } catch {
    // Continue.
  }

  return String(error)
}

// Manifest v2 polyfill
if (chrome.runtime.getManifest().manifest_version === 2) {
  chrome.action = chrome.browserAction
}

// eslint-disable-next-line no-unused-vars
const Utils = {
  agent: chrome.runtime.getURL('/').startsWith('moz-')
    ? 'firefox'
    : chrome.runtime.getURL('/').startsWith('safari-')
    ? 'safari'
    : 'chrome',

  /**
   * Use promises instead of callbacks
   * @param {Object} context
   * @param {String} method
   * @param  {...any} args
   */
  promisify(context, method, ...args) {
    return new Promise((resolve, reject) => {
      context[method](...args, (...args) => {
        if (chrome.runtime.lastError) {
          return reject(Utils.normalizeError(chrome.runtime.lastError))
        }

        resolve(...args)
      })
    })
  },

  /**
   * Open a browser tab
   * @param {String} url
   * @param {Boolean} active
   */
  open(url, active = true) {
    chrome.tabs.create({ url, active })
  },

  /**
   * Close current browser tab
   */
  close(tabId) {
    chrome.tabs.remove(tabId, () => {
      if (
        chrome.runtime.lastError &&
        !Utils.isMissingTabError(chrome.runtime.lastError)
      ) {
        // eslint-disable-next-line no-console
        console.error(
          'wappalyzer | utils |',
          Utils.normalizeError(chrome.runtime.lastError)
        )
      }
    })
  },

  getErrorMessage,

  normalizeError(error) {
    return error instanceof Error ? error : new Error(getErrorMessage(error))
  },

  isMissingTabError(error) {
    return /\b(No tab with id|Receiving end does not exist)\b/i.test(
      getErrorMessage(error)
    )
  },

  /**
   * Get value from local storage
   * @param {String} name
   * @param {string|mixed|null} defaultValue
   */
  async getOption(name, defaultValue = null) {
    try {
      /*
      try {
        const managed = await Utils.promisify(
          chrome.storage.managed,
          'get',
          name
        )

        if (managed[name] !== undefined) {
          return managed[name]
        }
      } catch {
        // Continue
      }
      */

      const option = await Utils.promisify(chrome.storage.local, 'get', name)

      if (option[name] !== undefined) {
        return option[name]
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('wappalyzer | utils |', Utils.normalizeError(error))
    }

    return defaultValue
  },

  /**
   * Set value in local storage
   * @param {String} name
   * @param {String} value
   */
  async setOption(name, value) {
    try {
      await Utils.promisify(chrome.storage.local, 'set', {
        [name]: value,
      })
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('wappalyzer | utils |', Utils.normalizeError(error))
    }
  },

  /**
   * Apply internationalization
   */
  i18n() {
    Array.from(document.querySelectorAll('[data-i18n]')).forEach(
      (node) => (node.innerHTML = chrome.i18n.getMessage(node.dataset.i18n))
    )
  },

  sendMessage(source, func, args) {
    return new Promise((resolve, reject) => {
      chrome.runtime.sendMessage(
        {
          source,
          func,
          args: args ? (Array.isArray(args) ? args : [args]) : [],
        },
        (response) => {
          chrome.runtime.lastError
            ? reject(Utils.normalizeError(chrome.runtime.lastError))
            : resolve(response)
        }
      )
    })
  },

  globEscape(string) {
    return string.replace(/\*/g, '\\*')
  },
}
