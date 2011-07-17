# install watchr
# $ sudo gem install watchr
#
# Run With:
# $ watchr spec.watchr
#

# --------------------------------------------------
# Helpers
# --------------------------------------------------

def project
  {
    :name => File.basename(File.dirname(__FILE__))
  }
end

def script

end

def notify(msg)
  system("growlnotify -n '#{project[:name]}' -t '#{project[:name]}' -m '#{msg}'")
end

def run(*cmds)
  system("clear")
  cmd = cmds.shift
  puts(cmds.join("\n"))

  script = case cmd
           when :rspec then "rake spec"
           when :features then "cucumber features"
           else
             "rspec #{cmd}"
           end

  msg = if success = system(script)
          "specs passed"
        else
          "specs failed"
        end
  notify(msg)

  run(*cmds) unless cmds.empty?
  run(:rspec) if success && ![:rspec, :features].find(cmd)
  return success
end

# features if 
# run(:rspec, :features)
run(:rspec)

# --------------------------------------------------
# Watchr Rules
# --------------------------------------------------
watch("^lib.*/(.*)\.rb")                { |m| run("spec/#{m[1]}_spec.rb") }
watch("^app/controllers/(.*).rb")       { |m| run("spec/controllers/#{m[1]}_controller_spec.rb") }
watch("^spec/controllers/(.*)_spec.rb") { |m| run("spec/controllers/#{m[1]}_spec.rb")}
watch("^app/models/(.*).rb")            { |m| run("spec/models/#{m[1]}_spec.rb") }
watch("^spec/models/(.*)_spec.rb")      { |m| run("spec/models/#{m[1]}_spec.rb") }
watch("spec.*/spec_helper\.rb")         { system( "padrino rake spec" ) }
watch("^spec/(.*)_spec\.rb")            { |m| run("spec/#{m[1]}_spec.rb") }


# watch("^lib.*/(.*)\.rb")                { |m| run(:features) }
# watch("^app/controllers/(.*).rb")       { |m| run(:features) }
# watch("^app/models/(.*).rb")            { |m| run(:features) }
# 
# watch("^features/step_definitions/(.*)\.rb") { |m| run(:features) }
# 
# watch("^features/(.*)\.feature")            { |m| run(:feature) }

# --------------------------------------------------
# Signal Handling
# --------------------------------------------------
# Ctrl-\
Signal.trap('QUIT') do
  puts " --- Running all specs ---\n\n"
  run_all_specs
end

# Ctrl-C
Signal.trap('INT') { abort("\n") }






