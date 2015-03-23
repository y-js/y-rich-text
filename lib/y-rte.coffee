_ = require 'underscore'

# Function that translates an index from start (absolute position) into a
# relative position in word index and offset
#
# @param [Integer] position the position
# @param [Rte] rte an rte instance
relativeFromAbsolute = (position, rte)->
    index = 0

    while position > 0
      if index >= rte._rte.words.length
        return {word: index, pos: 0}
      if rte._rte.words[index].word.length > position
        return {word: index, pos: position}
      else
        position -= rte._rte.words[index].word.length
        index += 1
    return {word: index, pos: position}

# Function that translates an index from start (absolute position) into a
# relative position in word index and offset
#
# @param [Option] relative the position
# @param [Rte] rte an rte instance
absoluteFromRelative = (index, offset, rte) ->
  absolute = offset
  if index > 0
    for i in [0..(index-1)]
      absolute += rte.getWord(i).word.length

  absolute

# XRegExp = require('xregexp').XRegExp
WordRegExp = /\S+\s*/g
PreSpacesRegExp = /^\s+/
PostSpacesRegExp = /\s+$/
# Simple class that contains a word and links to the selections pointing
# to it
class Word
  # Attribute containing the string
  @word = ''
  # Selections that have this word as left bound
  @left = []
  # Selections that have this word as right bound
  @right = []

  # Construct a new list of words
  # @param [String] word The initial string value
  # @return [Word] a word instance
  constructor: (@word) ->
    # Selections that have this word as left bound
    @left = []
    # Selections that have this word as right bound
    @right = []

  # Remove a selection from left or right array
  #
  # @param [Selection] selection the selection to remove
  # @param [Option] side the side where to remove the selection
  # @option side [String] left left side
  # @option side [String] right right side
  removeSel: (selection, side)->
    if side == "left"
      array = @left
    else if side == "right"
      array = @right
    else
      throw new Error "Invalid argument #{side}, expected 'left' or 'right'"
    index = 0
    for index in [0..array.length-1]
      if array[index].equals selection
        array.pop(index)
        break

  # Get index of word in rte list
  index: (rte) ->
    if not (rte instanceof Rte)
      throw new Error "Expected an RTE instance as first argument, got #{rte}"
    return rte._rte.words.indexOf @


# A class describing a selection with a style (bold, italic, …)
class Selection
  # Word that is the left bound
  @left = null
  # Word that is the right bound
  @right = null
  #   Construct a new selection using the index of the first and last character.
  #   Retrieves the position in (word, position) using an instance of rte
  #   @param [Integer] start index of the first character
  #   @param [Integer] end index of the last character
  #   @param [Rte] rte a rich-text editor (Rte) instance
  #   @option options [Object] style the style of the selection
  constructor: (start, end, rte, style)->
    if not _.isUndefined(start) and not _.isUndefined(end) and not _.isUndefined(rte)
      if !( _.isNumber(start) and
            _.isNumber(end))
        throw new Error "Expecting numbers as arguments"
      if not (rte instanceof Rte)
        throw new Error "Expecting an rte instance as third argument, got #{rte}"

      @rte = rte

      retStart = @_relativeFromAbsolute start
      retEnd = @_relativeFromAbsolute end

      @setStyle style

      @left = @rte.getWord retStart.word
      @leftPos = retStart.pos
      @right = @rte.getWord retEnd.word
      @rightPos = retEnd.pos

      @left.left.push @
      @right.right.push @

      @rte._rte.selections.push @


    else throw new Error "Wrong set of parameters
      #{start}, #{end}, #{rte}, #{style}"

  lt: (word2, pos2, side)->
    if not (_.isString side)
      throw new Error "Expected a string as first argument, got #{side}"

    if side == "left"
      word1 = @left
      pos1 = @leftPos
    else if side == "right"
      word1 = @right
      pos1 = @rightPos

    (word1 == word2 and pos1 <= pos2) or
     ((word1.index @rte) < (word2.index @rte))

  gt: (word2, pos2, side)->
    if not (_.isString side)
      throw new Error "Expected a string as first argument, got #{side}"

    if side == "left"
      word1 = @left
      pos1 = @leftPos
    else if side == "right"
      word1 = @right
      pos1 = @rightPos

    (word1 == word2 and pos1 >= pos2) or
    ((word1.index @rte) > (word2.index @rte))


  # Convert indexes from beginning of text to coordinates expressed in word and
  # position within word
  #
  # @param [Integer] position index of position to find
  _relativeFromAbsolute: (position)->
    relativeFromAbsolute position, @rte

  # Compares *the bounds* of two selections
  #
  # @param [Selection] s the selection to compare to this
  #
  equals: (selection)->
    @left == selection.left and
    @leftPos == selection.leftPos and
    @right == selection.right and
    @rightPos == selection.rightPos

  # Compares *the bounds* of two selections
  #
  # @param [Selection] s the selection to compare to this
  #
  notEquals: (selection) ->
    not @equals(selection)

  # Returns true if the given selection is in the current selection
  #
  # @param [Selection] selection the selection to compare to this
  #
  in: (selection) ->
    @gt(selection.left, selection.leftPos, "left") and
    @lt(selection.right, selection.rightPos, "right")

  # Returns true if the current selection is in the given selection
  #
  # @param [Selection] selection the selection to compare to this
  #
  contains: (selection) ->
    selection.in(@)


  # Returns true if the given selection and this selection are contiguous
  # and this selection is at left of the given one
  #
  # @param [Selection] selection the selection to compare to this
  atLeftOf: (selection) ->
    (@right == selection.left and
     @rightPos == selection.leftPos)

  #TODO
  setStyle: (@style) ->

  # Validate a selection if the start is before the end of the selection
  #
  isValid: ->
    @lt(@right, @rightPos, "left")


  # Try to merge the given selection with this selection
  #
  # @param [Selection] selection the selection to merge to
  #
  # @example
  #   1                 2                   3
  #   [  left selection ][  right selection ]
  #    becomes
  #   [           right selection           ]
  merge: (selection) ->
    if @ == selection
      return
    if @style != selection.style
      return
    if @atLeftOf selection
      leftSel = @
      rightSel = selection
    else if selection.atLeftOf @
      leftSel = selection
      rightSel = @
    else
      return

    # unbind words from left selection, remove it from selection list
    # expand the selection at right to the left end of previous left selection
    rightSel.left.removeSel rightSel, "left"

    rightSel.left = leftSel.left
    rightSel.leftPos = leftSel.leftPos

    leftSel.unbind()
    @rte.removeSel leftSel

  # Unbind selection from word
  unbind: ->
    @left.removeSel @, "left"
    @right.removeSel @, "right"

    @left = null
    @right = null

  # Bind selection to word
  bind: ->
    @left.left.push @
    @right.right.push @

  # Clone the current selection and apply style
  # @parameter [String] style the new style
  clone: (style) ->
    newSel = new Selection 0, 0, @rte, style

    newSel.unbind()

    newSel.left = @left
    newSel.leftPos = @leftPos

    newSel.right = @right
    newSel.rightPos = @rightPos

    newSel.bind()

    newSel

# Class describing the Rich Text Editor type
#
class Rte
  # @property [Options] _rte the RTE object
  # @param [String] content the initial content to set
  # @option _rte [Array<Selection>] selections array containing all the current selections
  # @option _rte [Array<String>] words array containing all the words of the text
  #
  constructor: (content = '')->
    if content.constructor isnt String
      throw new Error "Only accepts strings."
    @_rte = {}
    @_rte.styles = []
    @_rte.selections = []
    @_rte.cursorInformation = {}
    @_rte.words = []
    @push(content)

  _name: "Rich Text Editor"

  # _getModel:
  # _setModel:
  # observe:
  # unobserve:

  # @overload val()
  #   Return the value of the Rte instance as a non formatted string
  #
  # @overload val(content)
  #   Set the content of the Rte instance
  #   @param content [String] Set the strings of the Rte to this content
  val: (content)->
    if not _.isUndefined(content)
      # reset styles when replacing content
      @_rte.words = []
      @_rte.style = []
      @push(content)
    else
      # TODO: support breaks (br, new paragraph, …)
      (e.word for e in @_rte.words).join('')

  # Returns the word object of a word.
  # @param index [Integer] the index of the word to return
  getWord: (index) ->
    if @_rte.words.length == 0 or index == @_rte.words.length
      return new Word ""

    if not (0 <= index < @_rte.words.length)
      throw new Error "Index out of bounds #{index}"
    @_rte.words[index]

  # Returns the *word objects* within boundaries
  # @param begin [Integer] the first word the return
  # @param end [Integer] the first word /not/ to return
  getWords: (begin, end) ->
    if _.isUndefined(end)
      end = @_rte.words.length
    if not (0 <= begin <= end <= @_rte.words.length)
      return []

    ret = @_rte.words[begin..end]
    if ret
      ret
    else
      []

  # Set the content of a word
  # @param index [Integer] the index of the word to modify
  # @param content [String] the content to set the word to
  setWord: (index, content) ->
    if index == @_rte.words.length
      @_rte.words.push(new Word content)
    if not (0 <= index < @_rte.words.length)
      throw new Error "Index out of bounds"

    @_rte.words[index].word = content

  # Append new words at the end of the word list
  # @param [String] content the string to append
  push: (content) ->
    preSpaces = content.match PreSpacesRegExp
    if preSpaces isnt null
      @_rte.words.push(new Word (preSpaces[0]))
    words = content.match WordRegExp
    if _.isArray(words)
      for w in words
        @_rte.words.push (new Word w)

  # Insert words at position
  #
  # @param [Integer] position the position where to insert words
  # @param [Array<String>] words the words to insert at position
  #
  insertWords: (position, words)->
    # TODO: update selections
    if not _.isNumber position
      throw new Error "Expected a number as first parameter, got #{position}"
    if not _.isArray words
      throw new Error "Expected a string array as second parameter, got #{words}"
    if 0 <= position <= @_rte.words.length
      wordsObj = (new Word w for w in words)

      left = @_rte.words.slice(0, position)
      right = @_rte.words.slice(position)
      @_rte.words = left.concat(wordsObj).concat(right)

    else
      throw new Error 'Index #{position} out of bound in word list'


  # @overload deleteWords (start, end)
  # Delete all the words between start and end
  #
  # @param [Integer] start position of first word to delete
  # @param [Integer] end position of last word to delete
  #
  # @overload deleteWords (position)
  # Delete the word at position
  #
  # @param [Integer] position position the word to delete
  deleteWords: (start, end) ->
    if _.isUndefined(end)
      end = start+1

    if start <= end
      @_rte.words.splice(start, end-start)

  # Merge two words at position
  #
  # @param [Integer] n position of word where to perform merge. The merge will be done with the word at right (if any)
  #
  merge: (index) ->
    if 0 <= index < @_rte.words.length
      word = @getWord(index).word.trimRight()
      @deleteWords index
      pos = absoluteFromRelative index, 0, @
      @insert pos, word
    else
      throw new Error "Impossible to merge"

  # Delete text under selection
  #
  # @param [Selection] sel the selection to delete
  #
  deleteSel: (selection) ->
    if not selection.isValid()
      throw new Error "Invalid selection"

    left = selection.left
    right = selection.right

    leftIndex = left.index @
    rightIndex = right.index @

    newLeft = left.word.substring 0, selection.leftPos
    newRight = right.word.substring selection.rightPos

    if left == right
      @setWord leftIndex, (newLeft + newRight)

      # delete the words in between
      @deleteWords leftIndex+1, rightIndex
    else
      @setWord leftIndex, newLeft
      @setWord rightIndex, newRight

      # delete the words in between
      @deleteWords leftIndex+1, rightIndex
      # merge
      @merge leftIndex

  # Insert text at position
  #
  # @param [Integer] position The position where to insert text
  # @param [String] content the content to insert
  #
  insert: (position, content)->
    if not (_.isNumber position)
      throw new Error "Expected an integer as first argument"
    if not (_.isString content)
      throw new Error "Expected a string as second argument"

    if content.length == 0
      return

    ret = relativeFromAbsolute position, @

    index = ret.word   #position to work from
    pos = ret.pos

    preSpaces = content.match PreSpacesRegExp
    currWord = @getWord(index).word

    # move the spaces to the previous word if a pos == 0
    if preSpaces isnt null
      if pos == 0
        if index == 0
          index += 1
          @insertWord 0, (new Word '')
        prevWord = @getWord(index-1).word
        prevWord += preSpaces
        content = content.substring(preSpaces.length)
        @setWord (index-1), prevWord

    # insert the content at position
    currWord = currWord.substring(0, pos) + content + currWord.substring(pos)

    # cut the word
    newWords = currWord.match WordRegExp
    tmp = currWord.match PreSpacesRegExp
    if tmp isnt null
      newWords[0] = tmp + newWords[0]
    @setWord index, newWords[0]
    @insertWords index+1, newWords[1..]

  # Relative jump from position
  #
  _jump: (position, relJump) ->
    word = position.word
    pos = position.pos

    if jump < 0
      jump = Math.abs(jump)
      while jump > 0
        if pos < jump
          word -= 1
          jump -= pos
          pos = @getWord(word).word.length - 1

          if word < 0
            return null
        else
          pos -= jump
    else if jump > 0
      while jump > 0
        delta = pos + jump - @_rte.word[word].length + 1
        if delta > 0
          word += 1
          jump -= delta
          pos = 0

          if word >= @_rte.words.length
            return null
        else
          pos += jump
    else
      word = word
      pos = pos
    {word: word, pos: pos}

  # Set the style of the selection and try to extend as much
  # as possible existing ones
  #
  setStyle: (selection, style)->
    if not selection.isValid()
      throw new Error "Invalid selection"

    selection.style = style or ""

    # Link the boundary words to selection
    leftWord = selection.left
    rightWord = selection.right

    # Merge left…
    for tmpSelection in leftWord.right when tmpSelection
      tmpSelection.merge selection
    # …and right (only happens when selections are contiguous or overlapping
    # and have same style)
    for tmpSelection in rightWord.left when tmpSelection
      tmpSelection.merge selection

  # Apply a delta to the object
  # @see http://quilljs.com/docs/deltas/
  #
  delta: (deltas) ->
    position = 0
    for delta in deltas.ops
      if delta.retain?
        if delta.attributes?
          selection = new Selection position, (position + delta.retain), @
        position += delta.retain

      else if delta.delete?
        selection = new Selection position, (position + delta.delete), @
        @deleteSel selection

      else if delta.insert?
        @insert position, delta.insert
        position += delta.insert.length

      else
        throw new Error "Unknown operation"

      if delta.attributes?
        for attr in delta.attributes
          @setAttr(selection.clone().style = attr)

  # Remove a selection from selection list
  #
  # @param [Selection] selection the selection to remove
  removeSel: (selection) ->
    index = 0
    array = @_rte.selections
    for index in [0..array.length-1]
      if (array[index].equals(selection) and (array[index].style == selection.style))
        array.splice index, 1
        break

    # unbind selection
    selection.unbind

if window?
  window.Rte = Rte
  window.Selection = Selection
  window.Word = Word

if module?
  module.exports = [Rte, Selection, Word,
    relativeFromAbsolute, absoluteFromRelative]
