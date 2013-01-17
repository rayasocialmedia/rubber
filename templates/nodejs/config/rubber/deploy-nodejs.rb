namespace :rubber do

  namespace :nodejs do

    rubber.allow_optional_tasks(self)

    after "rubber:install_packages", "rubber:nodejs:install"

    task :install, :roles => :nodejs do
      rubber.sudo_script 'install_nodejs', <<-ENDSCRIPT
        apt-get update
        apt-get install build-essential g++
        if ! node --version | grep "#{rubber_env.nodejs_server_version}"; then
          # fetch the source
          wget http://nodejs.org/dist/v#{rubber_env.nodejs_server_version}/node-v#{rubber_env.nodejs_server_version}.tar.gz
          tar -xzf node-v#{rubber_env.nodejs_server_version}.tar.gz

          # build the binaries
          cd node-v#{rubber_env.nodejs_server_version}
          ./configure
          make
          make install

          # create the nodejs user
          if ! id nodejs; then
            adduser --system --group nodejs
          fi

          # cleanup the files
          cd ..
          rm -r node-v#{rubber_env.nodejs_server_version}
          rm node-v#{rubber_env.nodejs_server_version}.tar.gz
        fi
      ENDSCRIPT
    end

    after "rubber:bootstrap", "rubber:nodejs:bootstrap"

    task :bootstrap, :roles => :nodejs do
      # make directory to store the nodejs modules 
      rsudo "mkdir #{shared_path}/node_modules"
    end

    after 'deploy:update_code', 'rubber:nodejs:symlinks', 'rubber:nodejs:npm_install'

    desc "Creates symbolic link for node_modules"
    task :symlinks do
      rsudo "rm -r #{release_path}#{rubber_env.nodejs_root_directory}node_modules && ln -nfs #{shared_path}/node_modules #{release_path}#{rubber_env.nodejs_root_directory}node_modules"
    end

    desc "Installs any nodejs dependencies"
    task :npm_install do 
      rsudo "cd #{release_path}#{rubber_env.nodejs_root_directory} && npm install"
    end

    before "deploy:stop", "rubber:nodejs:stop"
    after "deploy:start", "rubber:nodejs:start"
    after "deploy:restart", "rubber:nodejs:restart"

    desc "Starts the nodejs server"
    task :start, :roles => :nodejs do
      rsudo "/sbin/start-stop-daemon --start --pidfile #{rubber_env.nodejs_server_pid_file} --user nodejs --group nodejs -b --make-pidfile --chuid nodejs --exec `which node` #{release_path}#{rubber_env.nodejs_root_directory}#{rubber_env.nodejs_app_file}"
    end

    desc "Stops the nodejs server"
    task :stop, :roles => :nodejs, :on_error => :continue do
      rsudo "/sbin/start-stop-daemon --stop --pidfile #{rubber_env.nodejs_server_pid_file} --user nodejs --group nodejs --exec `which node` #{release_path}#{rubber_env.nodejs_root_directory}#{rubber_env.nodejs_app_file}"
    end

    desc "Restarts the nodejs server"
    task :restart , :roles => :nodejs do
      stop
      start
    end

  end

end
