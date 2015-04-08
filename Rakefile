require "bundler/gem_tasks"

def specs(dir)
  FileList["spec/#{dir}/*_spec.rb"].shuffle.join(' ')
end

desc 'Runs all the specs'
task :spec do
  sh "bundle exec bacon #{specs('**')}"
end

task :default => :specs
