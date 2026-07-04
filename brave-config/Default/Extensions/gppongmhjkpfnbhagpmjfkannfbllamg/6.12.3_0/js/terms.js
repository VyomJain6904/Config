'use strict'
/* eslint-env browser */
/* globals Utils */

const { agent, i18n, getOption, setOption, sendMessage } = Utils

const Terms = {
  /**
   * Initialise terms
   */
  async init() {
    const el = {
      body: document.body,
      headerThemeDark: document.querySelector('.header__theme--dark'),
      headerThemeLight: document.querySelector('.header__theme--light'),
      headerThemes: document.querySelectorAll('.header__theme'),
      termsButtonAccept: document.querySelector('.terms__button--accept'),
      termsButtonDecline: document.querySelector('.terms__button--decline'),
      termsPrivacyOther: document.querySelector('.terms__privacy--other'),
      termsPrivacyFirefox: document.querySelector('.terms__privacy--firefox'),
    }

    // Dark mode
    const theme = await getOption('theme', 'light')

    if (theme === 'dark') {
      el.body.classList.add('dark')
    }

    // Privacy policy
    if (agent === 'firefox') {
      el.termsPrivacyOther.classList.add('terms__privacy--hidden')
      el.termsPrivacyFirefox.classList.remove('terms__privacy--hidden')
    }

    // Terms
    el.termsButtonAccept.addEventListener('click', async () => {
      await setOption('termsAccepted', true)
      await setOption('tracking', true)

      Terms.driver('closeCurrentTab')
    })

    el.termsButtonDecline.addEventListener('click', async () => {
      await setOption('termsAccepted', true)
      await setOption('tracking', false)

      Terms.driver('closeCurrentTab')
    })

    // Theme
    el.headerThemes.forEach((headerTheme) =>
      headerTheme.addEventListener('click', async () => {
        const theme = await getOption('theme', 'light')

        el.body.classList[theme === 'dark' ? 'remove' : 'add']('dark')
        el.body.classList[theme === 'dark' ? 'add' : 'remove']('light')
        el.headerThemeDark.classList[theme === 'dark' ? 'remove' : 'add'](
          'header__icon--hidden'
        )
        el.headerThemeLight.classList[theme === 'dark' ? 'add' : 'remove'](
          'header__icon--hidden'
        )

        await setOption('theme', theme === 'dark' ? 'light' : 'dark')
      })
    )

    // Apply internationalization
    i18n()
  },

  driver(func, args) {
    return sendMessage('terms.js', func, args)
  },

  /**
   * Log debug messages to the console
   * @param {String} message
   */
  log(message) {
    Terms.driver('log', message)
  },
}

if (/complete|interactive|loaded/.test(document.readyState)) {
  Terms.init()
} else {
  document.addEventListener('DOMContentLoaded', Terms.init)
}
