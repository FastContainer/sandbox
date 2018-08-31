# coding: utf-8
# frozen_string_literal: true

CleanSpawn.cgroup_root_path = '/sys/fs/cgroup/systemd'

module Container
  class << self
    def dispatch_after_smtp_auth
      list = {
        foo: '10.0.5.5',
        bar: '10.0.5.6'
      }

      req = Nginx::Request.new
      user = req.headers_in['Auth-User'].to_sym
      prot = req.headers_in['Auth-Protocol'].to_sym

      req.headers_out['Auth-Status'] = -> do
        unless list.keys.include? user
          debug("SMTP AUTH failed: unknown #{user}")
          return 'invalid user'
        end

        dispatch('postfix', list[user], 25)

        req.headers_out['Auth-Server'] = list[user]
        req.headers_out['Auth-Port'] = { smtp: '25', imap: '143' }

        debug("SMTP AUTH success: #{user} to #{list[user]}:25")
        return 'OK'
      end.call
    end

    def dispatch(haco = nil, ip = nil, port = nil)
      raise "Not enough container info -- haco: #{haco}, ip: #{ip} port: #{port}" \
        if haco.nil? || ip.nil? || port.nil?

      result = "#{ip}:#{port}"
      return result if listen?(ip, port)

      debug('Launch a container')
      run(haco, ip, port)
      debug("Return ip: #{ip} port: #{port}")
      return result

    rescue => e
      err(e.message)
      return ''
    end

    def debug(m)
      Nginx.errlogger Nginx::LOG_DEBUG, "#{self.name} -- #{m}"
    rescue
      Nginx::Stream.log Nginx::Stream::LOG_DEBUG, "#{self.name} -- #{m}"
    end

    def err(m)
      Nginx.errlogger Nginx::LOG_ERR, "#{self.name} -- #{m}"
    rescue
      Nginx::Stream.log Nginx::Stream::LOG_ERR, "#{self.name} -- #{m}"
    end

    def run(haco, ip, port)
      cmd = ['/usr/bin/haconiwa', 'run', "/var/lib/haconiwa/hacos/#{haco}.haco"].join(' ')
      shell_cmd = ['/bin/bash', '-c', "#{cmd} >> /var/log/nginx/haconiwa.log 2>&1"]
      debug(shell_cmd.join(' '))
      clean_spawn(*shell_cmd)
      wait_for_listen("/var/lock/.#{haco}.hacolock", ip, port)
    end

    def wait_for_listen(lockfile, ip, port, max = 600)
      while true
        listen = listen?(ip, port)
        file = File.exist?(lockfile)

        return if listen && file
        debug("Stil no listen: #{ip}:#{port}") unless listen
        debug("Stil no lockfile: #{lockfile}'") unless file

        usleep 100 * 1000
        max -= 1
        raise 'it take too long time to begin listening, timeout' if max <= 0
      end
    end

    def listen?(ip, port)
      ::FastRemoteCheck.new('127.0.0.1', 0, ip, port, 3).connectable?
    rescue
      false
    end
  end
end

def req
  @req ||= Nginx::Request.new
end

def nginx_local_port
  Nginx::Stream::Connection.local_port
rescue
  req = Nginx::Request.new
  req.var.server_port.to_i
end

lambda do
  port = nginx_local_port

  # smtp auth api
  if port == 58080
    return Container.dispatch_after_smtp_auth
  end

  case port
  when 80
    haco = 'nginx'
    cip = '10.0.5.2'
  when 8022
    haco = 'ssh'
    cip = '10.0.5.3'
  when 8025
    haco = 'postfix'
    cip = '10.0.5.4'
  when 8587
    haco = 'postfix'
    cip = '10.0.5.4'
  when 8465
    haco = 'postfix'
    cip = '10.0.5.4'
  end

  if port == 80
    cport = port
  else
    cport = port - 8000
    c = Nginx::Stream::Connection.new 'dynamic_server'
    c.upstream_server = "#{cip}:#{cport}"
  end

  return Container.dispatch(haco, cip, cport)
end.call
