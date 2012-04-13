# SauceBot Module: AutoCommercial

Sauce = require '../sauce'
db    = require '../saucedb'
io    = require '../ioutil'

{ConfigDTO} = require '../dto' 

# Module description
exports.name        = 'AutoCommercial'
exports.version     = '1.0'
exports.description = 'Automatic commercials for jtv partners'

io.module '[AutoCommercial] Init'

class AutoCommercial
    constructor: (@channel) ->
        @comDTO = new ConfigDTO @channel, 'autocommercial', ['state', 'delay', 'messages']
        
        @messages = []
        @loaded = false
        
        
    load: ->
        io.module "[AutoCommercial] Loading for #{@channel.id}: #{@channel.name}"
        
        @registerHandlers() unless @loaded
        
        @comDTO.load()
        
    unload: ->
        io.module "[AutoCommercial] Unloading from #{@channel.id}: #{@channel.name}"


    registerHandlers: ->
        # !commercial on - Enable auto-commercials
        @channel.register this, "commercial on"      , Sauce.Level.Admin,
            (user,args,bot) =>
                @cmdEnableCommercial
        
        # !commercial off - Disable auto-commercials
        @channel.register this, "commercial off"     , Sauce.Level.Admin,
            (user,args,bot) =>
                @cmdDisableCommercial
                
                
    cmdEnableCommercial: ->
        @comDTO.set 'state', 1
    
    
    cmdDisableCommercial: ->
        @comDTO.set 'state', 0
        

    updateMessagesList: (now) ->
        delay = @comDTO.get 'delay'
        delay = 30 if delay < 30
        limit = now - (delay * 1000)
        
        @messages.push now
        @messages = (message for message in @messages when message > limit)
        
        
    messagesSinceLast: ->
        @messages.length

    handle: (user, msg, bot) ->
        return unless @comDTO.get 'state'
        now = Date.now()
        
        @updateMessagesList now
        msgsLimit = @comDTO.get 'messages'
        msgsLimit = 20 if msgsLimit < 20
        return unless @messagesSinceLast >= msgsLimit
        
        bot.commercial()

        
exports.New = (channel) -> new AutoCommercial channel
