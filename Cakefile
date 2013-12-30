# Cakefile

{spawn,exec} = require "child_process"

task "clean", "remove build dir", ->
    exec "rm -rf lib"

task "build", "build coffee ./src into ./lib", ->
    exec "./node_modules/.bin/coffee -o lib/ -c src/"

task "test", "run tests", ->
    exec "NODE_ENV=test ./node_modules/.bin/mocha --compilers coffee:coffee-script --reporter tap --colors",
        (err, output) ->
            throw err if err
            console.log output
    
task "watch-test", "run tests continually", ->
    mocha = spawn "./node_modules/.bin/mocha",
        [ "--compilers", "coffee:coffee-script", "--reporter", "min", "--colors", "-w" ],
        { stdio: 'inherit' }
    mocha.on 'error', (error) -> console.error error

task "dist", "build for dist", ->
    invoke 'clean'
    invoke 'build'
    invoke 'test'
