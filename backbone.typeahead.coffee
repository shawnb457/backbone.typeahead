class Backbone.TypeaheadCollection extends Backbone.Collection
  _tokenize: (s) ->
    s = $.trim(s)
    return null if s.length is 0

    s.toLowerCase().split(/[\s\-_]+/)

  _tokenizeModel: (model) ->
    throw new Error('Missing typeaheadAttributes value') unless @typeaheadAttributes?

    _.uniq(@_tokenize(_.map(@typeaheadAttributes, (att) -> model.get(att)).join(' ')))

  _addToIndex: (models) ->
    if _.isArray(models) then models.slice() else [models]

    for model in models
      tokens = @_tokenizeModel(model)
      id = if model.id? then model.id else model.cid

      @_tokens[id] = tokens

      for t in tokens
        character = t.charAt(0)
        adjacency = @_adjacency[character] ||= [id]
        adjacency.push(id) unless ~_.indexOf(adjacency, id)

  _removeFromIndex: (models) ->
    if _.isArray(models) then models.slice() else [models]

    ids = _.pluck(models, 'id')

    delete @_tokens[id] for id in ids

    for k,v of @_adjacency
      @_adjacency[k] = _.without(v, ids)

  _rebuildIndex: ->
    @_adjacency = {}
    @_tokens = {}
    @_addToIndex @models

  _facetMatch: (facets, attributes) ->
    for k,v of facets
      return false if v? and v isnt attributes[k]

    return true

  typeaheadIndexer: (facets) ->
    return null unless facets? and _.keys(facets).length > 0
    _.map(@where(facets), (m) -> if m.id? then m.id else m.cid)

  typeahead: (query, facets) ->
    throw new Error('Index is not built') unless @_adjacency?

    queryTokens = @_tokenize(query)
    suggestions = []
    lists = []
    shortestList = _.keys(@_byId)
    firstChars = _(queryTokens).chain().map((t) -> t.charAt(0)).uniq().value()

    _.all firstChars, (firstChar) =>
      list = @_adjacency[firstChar]

      return false unless list?

      lists.push list
      shortestList = list if list.length < shortestList.length

      true

    return [] if lists.length < firstChars.length

    facetList = @typeaheadIndexer(facets)
    lists.push facetList if facetList?
    shortestList = facetList if facetList? and facetList.length < shortestList.length

    for id in shortestList
      isCandidate = _.every lists, (list) ->
        ~_.indexOf(list, id)

      isMatch = isCandidate and _.every queryTokens, (qt) =>
        _.some @_tokens[id], (t) ->
          t.indexOf(qt) is 0

      if isMatch
        item = @get(id)

        if @typeaheadPreserveOrder
          suggestions[@indexOf(item)] = item
        else
          suggestions.push item

    suggestions

  _reset: ->
    @_tokens = {}
    @_adjacency = {}
    super

  #TODO: do this smarter
  set: (models, options) ->
    super
    @_rebuildIndex()
    @

  #TODO: do this smarter
  remove: (models, options) ->
    super
    @_rebuildIndex()
    @

  _onModelEvent: (event, model, collection, options) ->
    if event is "change:#{model.idAttribute}" or _.indexOf(_.map(@typeaheadAttributes, (att) -> 'change:' + att), event) >= 0
      @_removeFromIndex model
      @_addToIndex model

    super