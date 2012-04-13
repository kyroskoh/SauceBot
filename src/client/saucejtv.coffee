
# Node.js
color      = require 'colors'
term       = require 'readline'
util       = require 'util'
fs         = require 'fs'

# SauceBot
io         = require '../common/ioutil'
config     = require '../common/config'
{Client}   = require '../common/socket'
{Term}     = require '../common/term'
{Channel}  = require './saucechan'

# CONFIG
{server, highlight, accounts} = config.load 'jtv'

HOST = server.host
PORT = server.port

HIGHLIGHT = new RegExp highlight.join('|'), 'i'

sauce = new Client HOST, PORT

sauce.on 'say', (data) ->
    {chan, msg} = data
    bot.say chan, msg for _, bot of bots


sauce.on 'commercial', (data) ->
    {chan} = data
    for _, bot of bots
        bot.say chan "Commercial incoming! Please disable ad-blockers if you want to support #{chan}. <3"
        bot.sayRaw chan '/commercial'


sauce.on 'error', (data) ->
    io.error data.msg
    

class Bot
    constructor: (@name, @password) ->
        @channels = {}
        
    get: (cname) ->
        @channels[cname.toLowerCase()]
        
    add: (cname) ->
        @remove cname
        lc = cname.toLowerCase()
        
        chan = new Channel cname, @name, @password
        @channels[lc] = chan
       
        chan.on 'message', (args) =>
            {from, message, op} = args
            
            prefix = if op then '@' else ' '
           
            if HIGHLIGHT.test message
                io.irc cname, prefix + from, message.green.inverse
            else
                io.irc cname, prefix + from, message
               
            sauce.emit 'msg',
                chan: lc
                user: from
                msg : message
                op  : op
               
           
        chan.on 'error', (msg) =>
            io.error "Error in channel #{@name}/#{cname}:"
            for key, val of msg
                io.error "#{key.bold} = #{val}"
           
        chan.on 'connected', =>
            io.socket "Connected to #{@name}/#{cname.bold}"
           
        chan.on 'disconnecting', =>
            io.socket "Disconnecting from #{@name}/#{cname.bold}"
           
        chan.on 'connecting', =>
            io.debug "Connecting to #{@name}/#{cname.bold}..."
           
           
        chan.connect()
       
    remove: (name) ->
        lc = name.toLowerCase()
        chan = @channels[lc]
        if chan?
            chan.part()
            delete @channels[lc]
            
    list: ->
        #io.debug @name + ": " + @channels
        (name for name, _ of @channels)
        
    say: (chan, msg) ->
        if (channel = @get chan)?
            channel.say msg
            io.irc channel.name, @name, msg.cyan
            
                    
    sayRaw: (chan, msg) ->
        channel.sayRaw msg if (channel = @get chan)?
        

bots = {}
currentBot = 'SauceBot'

delay = 0

for account in accounts
    botName = account.username
    bot = new Bot botName, account.password

    for chan in account.channels
        do (bot, chan) ->
            delay++
            setTimeout ->
                bot.add chan
            , (delay * 1000)

    bots[botName.toLowerCase()] = bot
        

termPart = (name, chan) ->
    bots[name.toLowerCase()].remove chan
        
        
termJoin = (name, chan) ->
    bots[name.toLowerCase()].add chan
    
    
termSay = (name, chan, msg) ->
    bots[name.toLowerCase()].sayRaw chan, msg
    io.irc chan, name, msg
    
termUse = (bot) ->
    io.debug "Switched to #{bot.bold}"
    
termList = ->
    for name, bot of bots
        console.log " #{name.underline.bold.blue}"
        console.log "\t" + (chan.magenta for chan in bot.list()).join(', ')
        
termClose = ->
    for _, {channels} of bots
        chan.part() for __, chan of channels
            
    setTimeout ->
        process.exit()
    , 2000

        
chanList = -> bots[currentBot.toLowerCase()].list()
botList  = -> Object.keys bots 
        

# SauceBot terminal handler
term = new Term currentBot


term.on 'part', [chanList], (chan) ->
    termPart currentBot, chan
   
term.on 'join', [true], (chan) ->
    termJoin currentBot, chan

term.on 'say', [chanList, true], (chan, msg) ->
    termSay currentBot, chan, msg
    
term.on 'list', [], ->
    termList()
    
term.on 'use', [botList], (bot) ->
    termUse bot
    currentBot = bot
    term.setPrompt currentBot
    
term.on 'close', [], ->
    termClose()

