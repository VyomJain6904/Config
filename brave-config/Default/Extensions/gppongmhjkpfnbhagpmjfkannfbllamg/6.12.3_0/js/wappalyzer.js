'use strict'

function toArray(value) {
  return Array.isArray(value) ? value : [value]
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

const benchmarkEnabled =
  typeof process !== 'undefined' ? !!process.env.WAPPALYZER_BENCHMARK : false

const versionPattern = /^[A-Za-z0-9._-]+$/

let benchmarks = []

function benchmark(duration, pattern, value = '', technology) {
  if (!benchmarkEnabled) {
    return
  }

  benchmarks.push({
    duration,
    pattern: String(pattern.regex),
    value: String(value).slice(0, 100),
    valueLength: value.length,
    technology: technology.name,
  })
}

function benchmarkSummary() {
  if (!benchmarkEnabled) {
    return
  }

  const totalPatterns = Object.values(benchmarks).length
  const totalDuration = Object.values(benchmarks).reduce(
    (sum, { duration }) => sum + duration,
    0
  )

  // eslint-disable-next-line no-console
  console.log({
    totalPatterns,
    totalDuration,
    averageDuration: Math.round(totalDuration / totalPatterns),
    slowestTechnologies: Object.values(
      benchmarks.reduce((benchmarks, { duration, technology }) => {
        if (benchmarks[technology]) {
          benchmarks[technology].duration += duration
        } else {
          benchmarks[technology] = { technology, duration }
        }

        return benchmarks
      }, {})
    )
      .sort(({ duration: a }, { duration: b }) => (a > b ? -1 : 1))
      .filter(({ duration }) => duration)
      .slice(0, 5)
      .reduce(
        (technologies, { technology, duration }) => ({
          ...technologies,
          [technology]: duration,
        }),
        {}
      ),
    slowestPatterns: Object.values(benchmarks)
      .sort(({ duration: a }, { duration: b }) => (a > b ? -1 : 1))
      .filter(({ duration }) => duration)
      .slice(0, 5),
  })
}

const Wappalyzer = {
  normalizeVersion(version = '') {
    version = String(version || '').trim()

    return version && versionPattern.test(version) ? version : ''
  },

  technologies: [],
  technologiesByType: {},
  categories: [],
  requires: [],
  categoryRequires: [],

  slugify: (string) =>
    string
      .toLowerCase()
      .replace(/[^a-z0-9-]/g, '-')
      .replace(/--+/g, '-')
      .replace(/(?:^-|-$)/g, ''),

  getTechnology: (name) =>
    [
      ...Wappalyzer.technologies,
      ...Wappalyzer.requires
        .map((requirement) => requirement?.technologies || [])
        .flat(),
      ...Wappalyzer.categoryRequires
        .map((requirement) => requirement?.technologies || [])
        .flat(),
    ].find((technology) => technology?.name === name),

  getCategory: (id) =>
    Wappalyzer.categories.find((category) => category?.id === id),

  getTechnologiesByTypes(types = []) {
    const seen = new Set()
    const technologies = []

    for (const type of [...new Set(types)]) {
      if (!Wappalyzer.technologiesByType[type]) {
        Wappalyzer.technologiesByType[type] = Wappalyzer.technologies.filter(
          (technology) => hasValues(technology[type])
        )
      }

      const matches = Wappalyzer.technologiesByType[type]

      for (const technology of matches) {
        if (!technology?.name || seen.has(technology.name)) {
          continue
        }

        seen.add(technology.name)
        technologies.push(technology)
      }
    }

    return technologies
  },

  /**
   * Resolve promises for implied technology.
   * @param {Array} detections
   */
  resolve(detections = []) {
    const validDetections = detections.filter(
      ({ technology }) => technology?.name
    )
    const resolved = validDetections.reduce(
      (resolved, { technology, lastUrl }) => {
        if (
          resolved.findIndex(
            (detection) => detection?.technology?.name === technology?.name
          ) === -1
        ) {
          let version = ''
          let confidence = 0
          let rootPath

          validDetections
            .filter(
              (detection) => detection?.technology?.name === technology.name
            )
            .forEach(
              ({
                technology: { name },
                pattern,
                version: _version = '',
                rootPath: _rootPath,
              }) => {
                const normalizedVersion = Wappalyzer.normalizeVersion(_version)

                confidence = Math.min(100, confidence + pattern.confidence)
                version =
                  normalizedVersion.length > version.length &&
                  normalizedVersion.length <= 15 &&
                  (parseInt(normalizedVersion, 10) || 0) < 10000 // Ignore long numeric strings like timestamps
                    ? normalizedVersion
                    : version
                rootPath = rootPath || _rootPath || undefined
              }
            )

          resolved.push({ technology, confidence, version, rootPath, lastUrl })
        }

        return resolved
      },
      []
    )

    Wappalyzer.resolveExcludes(resolved)
    Wappalyzer.resolveImplies(resolved)

    const priority = ({ technology: { categories = [] } }) =>
      categories.reduce(
        (max, id) => Math.max(max, Wappalyzer.getCategory(id)?.priority || 0),
        0
      )

    return resolved
      .sort((a, b) => (priority(a) > priority(b) ? 1 : -1))
      .map(
        ({
          technology: {
            name,
            description,
            slug,
            categories,
            icon,
            website,
            pricing,
            cpe,
          },
          confidence,
          version,
          rootPath,
          lastUrl,
        }) => ({
          name,
          description,
          slug,
          categories: categories
            .map((id) => Wappalyzer.getCategory(id))
            .filter(Boolean),
          confidence,
          version,
          icon,
          website,
          pricing,
          cpe,
          rootPath,
          lastUrl,
        })
      )
  },

  /**
   * Resolve promises for version of technology.
   * @param {Promise} resolved
   * @param match
   */
  resolveVersion({ version, regex }, match) {
    let resolved = version

    if (version) {
      const matches = regex.exec(match)

      if (matches) {
        matches.forEach((match, index) => {
          if (String(match).length > 10) {
            return
          }

          // Parse ternary operator
          const ternary = new RegExp(`\\\\${index}\\?([^:]+):(.*)$`).exec(
            version
          )

          if (ternary && ternary.length === 3) {
            resolved = version.replace(
              ternary[0],
              match ? ternary[1] : ternary[2]
            )
          }

          // Replace back references
          resolved = resolved
            .trim()
            .replace(new RegExp(`\\\\${index}`, 'g'), match || '')
        })

        // Remove unmatched back references
        resolved = resolved.replace(/\\\d/, '')
      }
    }

    return Wappalyzer.normalizeVersion(resolved)
  },

  /**
   * Resolve promises for excluded technology.
   * @param {Promise} resolved
   */
  resolveExcludes(resolved) {
    resolved.forEach(({ technology }) => {
      technology.excludes.forEach(({ name }) => {
        const excluded = Wappalyzer.getTechnology(name)

        if (!excluded) {
          throw new Error(`Excluded technology does not exist: ${name}`)
        }

        let index

        do {
          index = resolved.findIndex(
            (detection) => detection?.technology?.name === excluded.name
          )

          if (index !== -1) {
            resolved.splice(index, 1)
          }
        } while (index !== -1)
      })
    })
  },

  /**
   * Resolve promises for implied technology.
   * @param {Promise} resolved
   */
  resolveImplies(resolved) {
    let done = false

    do {
      done = true

      resolved.forEach(({ technology, confidence, lastUrl }) => {
        technology.implies.forEach(
          ({ name, confidence: _confidence, version }) => {
            const implied = Wappalyzer.getTechnology(name)

            if (!implied) {
              throw new Error(`Implied technology does not exist: ${name}`)
            }

            if (
              resolved.findIndex(
                (detection) => detection?.technology?.name === implied.name
              ) === -1
            ) {
              resolved.push({
                technology: implied,
                confidence: Math.min(confidence, _confidence),
                version: version || '',
                lastUrl,
              })

              done = false
            }
          }
        )
      })
    } while (resolved.length && !done)
  },

  /**
   * Initialize analyzation.
   * @param {*} param0
   */
  analyze(items, technologies = Wappalyzer.technologies) {
    benchmarks = []

    const oo = Wappalyzer.analyzeOneToOne
    const om = Wappalyzer.analyzeOneToMany
    const mm = Wappalyzer.analyzeManyToMany

    const relations = {
      certIssuer: oo,
      cookies: mm,
      css: oo,
      dns: mm,
      headers: mm,
      meta: mm,
      probe: mm,
      robots: oo,
      scriptSrc: om,
      scripts: oo,
      text: oo,
      url: oo,
      xhr: oo,
    }
    const itemTypes = Object.keys(relations).filter((type) =>
      hasValues(items[type])
    )
    const relevantTechnologies =
      technologies === Wappalyzer.technologies
        ? Wappalyzer.getTechnologiesByTypes(itemTypes)
        : technologies

    try {
      const detections = relevantTechnologies
        .map((technology) =>
          itemTypes
            .map(
              (type) =>
                items[type] && relations[type](technology, type, items[type])
            )
            .flat()
        )
        .flat()
        .filter((technology) => technology)

      benchmarkSummary()

      return detections
    } catch (error) {
      throw new Error(error.message || error.toString())
    }
  },

  /**
   * Extract technologies from data collected.
   * @param {object} data
   */
  setTechnologies(data) {
    const transform = Wappalyzer.transformPatterns

    Wappalyzer.technologies = Object.keys(data).reduce((technologies, name) => {
      const {
        cats,
        certIssuer,
        cookies,
        cpe,
        css,
        description,
        dns,
        dom,
        excludes,
        headers,
        icon,
        implies,
        js,
        meta,
        pricing,
        probe,
        requires,
        requiresCategory,
        robots,
        scriptSrc,
        scripts,
        text,
        url,
        website,
        xhr,
      } = data[name]

      technologies.push({
        categories: cats || [],
        certIssuer: transform(certIssuer),
        cookies: transform(cookies),
        cpe: cpe || null,
        css: transform(css),
        description: description || null,
        dns: transform(dns),
        dom: transform(
          typeof dom === 'string' || Array.isArray(dom)
            ? toArray(dom).reduce(
                (dom, selector) => ({ ...dom, [selector]: { exists: '' } }),
                {}
              )
            : dom,
          true,
          false
        ),
        excludes: transform(excludes).map(({ value }) => ({ name: value })),
        headers: transform(headers),
        icon: icon || 'default.svg',
        implies: transform(implies).map(({ value, confidence, version }) => ({
          name: value,
          confidence,
          version,
        })),
        js: transform(js, true),
        meta: transform(meta),
        name,
        pricing: pricing || [],
        probe: transform(probe, true),
        requires: transform(requires).map(({ value }) => ({ name: value })),
        requiresCategory: transform(requiresCategory).map(({ value }) => ({
          id: value,
        })),
        robots: transform(robots),
        scriptSrc: transform(scriptSrc),
        scripts: transform(scripts),
        slug: Wappalyzer.slugify(name),
        text: transform(text),
        url: transform(url),
        website: website || null,
        xhr: transform(xhr),
      })

      return technologies
    }, [])

    Wappalyzer.technologies
      .filter(({ requires }) => requires.length)
      .forEach((technology) =>
        technology.requires.forEach(({ name }) => {
          if (!Wappalyzer.getTechnology(name)) {
            throw new Error(`Required technology does not exist: ${name}`)
          }

          Wappalyzer.requires[name] = Wappalyzer.requires[name] || []

          Wappalyzer.requires[name].push(technology)
        })
      )

    Wappalyzer.requires = Object.keys(Wappalyzer.requires).map((name) => ({
      name,
      technologies: Wappalyzer.requires[name],
    }))

    Wappalyzer.technologies
      .filter(({ requiresCategory }) => requiresCategory.length)
      .forEach((technology) =>
        technology.requiresCategory.forEach(({ id }) => {
          Wappalyzer.categoryRequires[id] =
            Wappalyzer.categoryRequires[id] || []

          Wappalyzer.categoryRequires[id].push(technology)
        })
      )

    Wappalyzer.categoryRequires = Object.keys(Wappalyzer.categoryRequires).map(
      (id) => ({
        categoryId: parseInt(id, 10),
        technologies: Wappalyzer.categoryRequires[id],
      })
    )

    Wappalyzer.technologies = Wappalyzer.technologies.filter(
      ({ requires, requiresCategory }) =>
        !requires.length && !requiresCategory.length
    )
    Wappalyzer.technologiesByType = {}
  },

  /**
   * Assign categories for data.
   * @param {Object} data
   */
  setCategories(data) {
    Wappalyzer.categories = Object.keys(data)
      .reduce((categories, id) => {
        const category = data[id]

        categories.push({
          id: parseInt(id, 10),
          slug: Wappalyzer.slugify(category.name),
          ...category,
        })

        return categories
      }, [])
      .sort(({ priority: a }, { priority: b }) => (a > b ? -1 : 0))
  },

  /**
   * Transform patterns for internal use.
   * @param {string|array} patterns
   * @param {boolean} caseSensitive
   */
  transformPatterns(patterns, caseSensitive = false, isRegex = true) {
    if (!patterns) {
      return []
    }

    if (
      typeof patterns === 'string' ||
      typeof patterns === 'number' ||
      Array.isArray(patterns)
    ) {
      patterns = { main: patterns }
    }

    const parsed = Object.keys(patterns).reduce((parsed, key) => {
      parsed[caseSensitive ? key : key.toLowerCase()] = toArray(
        patterns[key]
      ).map((pattern) => Wappalyzer.parsePattern(pattern, isRegex))

      return parsed
    }, {})

    return 'main' in parsed ? parsed.main : parsed
  },

  /**
   * Extract information from regex pattern.
   * @param {string|object} pattern
   */
  parsePattern(pattern, isRegex = true) {
    if (typeof pattern === 'object') {
      return Object.keys(pattern).reduce(
        (parsed, key) => ({
          ...parsed,
          [key]: Wappalyzer.parsePattern(pattern[key]),
        }),
        {}
      )
    } else {
      const { value, regex, confidence, version } = pattern
        .toString()
        .split('\\;')
        .reduce((attrs, attr, i) => {
          if (i) {
            // Key value pairs
            attr = attr.split(':')

            if (attr.length > 1) {
              attrs[attr.shift()] = attr.join(':')
            }
          } else {
            attrs.value = typeof pattern === 'number' ? pattern : attr

            attrs.regex = new RegExp(
              isRegex
                ? attr
                    // Escape slashes
                    .replace(/\//g, '\\/')
                    // Optimise quantifiers for long strings
                    .replace(/\\\+/g, '__escapedPlus__')
                    .replace(/\+/g, '{1,250}')
                    .replace(/\*/g, '{0,250}')
                    .replace(/__escapedPlus__/g, '\\+')
                : '',
              'i'
            )
          }

          return attrs
        }, {})

      return {
        value,
        regex,
        confidence: parseInt(confidence || 100, 10),
        version: version || '',
      }
    }
  },

  /**
   * @todo describe
   * @param {Object} technology
   * @param {String} type
   * @param {String} value
   */
  analyzeOneToOne(technology, type, value) {
    return technology[type].reduce((technologies, pattern) => {
      const startTime = Date.now()

      const matches = pattern.regex.exec(value)

      if (matches) {
        technologies.push({
          technology,
          pattern: {
            ...pattern,
            type,
            value,
            match: matches[0],
          },
          version: Wappalyzer.resolveVersion(pattern, value),
        })
      }

      benchmark(Date.now() - startTime, pattern, value, technology)

      return technologies
    }, [])
  },

  /**
   * @todo update
   * @param {Object} technology
   * @param {String} type
   * @param {Array} items
   */
  analyzeOneToMany(technology, type, items = []) {
    return items.reduce((technologies, value) => {
      const patterns = technology[type] || []

      patterns.forEach((pattern) => {
        const startTime = Date.now()

        const matches = pattern.regex.exec(value)

        if (matches) {
          technologies.push({
            technology,
            pattern: {
              ...pattern,
              type,
              value,
              match: matches[0],
            },
            version: Wappalyzer.resolveVersion(pattern, value),
          })
        }

        benchmark(Date.now() - startTime, pattern, value, technology)
      })

      return technologies
    }, [])
  },

  /**
   *
   * @param {Object} technology
   * @param {string} types
   * @param {Array} items
   */
  analyzeManyToMany(technology, types, items = {}) {
    const [type, ...subtypes] = types.split('.')

    return Object.keys(technology[type]).reduce((technologies, key) => {
      const patterns = technology[type][key] || []
      const values = items[key] || []

      patterns.forEach((_pattern) => {
        const pattern = (subtypes || []).reduce(
          (pattern, subtype) => pattern[subtype] || {},
          _pattern
        )

        values.forEach((value) => {
          const startTime = Date.now()

          const matches = pattern.regex.exec(value)

          if (matches) {
            technologies.push({
              technology,
              pattern: {
                ...pattern,
                type,
                value,
                match: matches[0],
              },
              version: Wappalyzer.resolveVersion(pattern, value),
            })
          }

          benchmark(Date.now() - startTime, pattern, value, technology)
        })
      })

      return technologies
    }, [])
  },
}

if (typeof module !== 'undefined') {
  module.exports = Wappalyzer
}
