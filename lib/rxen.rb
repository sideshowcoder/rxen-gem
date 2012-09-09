#!/usr/bin/env ruby

# Access via XML-RPC
require "xmlrpc/client"

# Read Config json file
require "rubygems"
require "json"

# Override XMLRPC Client to not throw a waring on self sign Certificate because 
# XenServer Certificates are always self signed

require "net/https"
require "openssl"
require "pp"

# enable debugger
# require "ruby-debug"


# Get rid of message that Cerificate from Server is self signed, since XenServer uses
# a self signed Cert in the default case and we know to which Server we connect anyway
module SELF_SSL

	class Net_HTTP < Net::HTTP
		def initialize(*args)
			super
			@ssl_context = OpenSSL::SSL::SSLContext.new
			# Set verify mode to VERIFY_NONE to not display a warning on 
			# self signed certificates
			@ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
		end
	end
 
	class XMLRPC_Client < XMLRPC::Client
		def initialize(*args)
			super
			# Use patched NET::HTTP module for XMLRPC
			@http = SELF_SSL::Net_HTTP.new( @host, @port, 
						       @proxy_host,@proxy_port )
			@http.use_ssl = @use_ssl if @use_ssl
			@http.read_timeout = @timeout
			@http.open_timeout = @timeout
		end
	end

end


# XenAPI 

# Define Xen Api Error to make clearer it clearer Exception belongs to XenApi
class XenApiError < RuntimeError; end
# Define Config Error
class XenApiConfigError < RuntimeError; end

# Handle a session with a given XenServer
class Session

	# Methods to respond to
	RPC_METHODS = {		
			# Login / Logout 
			:login => /^login/,					
			:logout => /^logout/,
			
			# Session
			:session_change_password => /^session_change_password/,	
			:session_get_all_subject_identifiers => /^session_get_all_subject_identifiers/,
			:session_logout_subject_identifier => /^session_logout_subject_identifier/,
			:session_get_uuid => /^session_get_uuid/,
			:session_get_this_user => /^session_get_this_user/,
			:session_get_this_host => /^session_get_this_host/,
			:session_get_last_active => /^session_get_last_active/,
			:session_get_pool => /^session_get_pool/,
			:session_get_other_config => /^session_get_other_config/,
			:session_set_other_config => /^session_set_other_config/,

			# Task
			:task_create => /^task_create/,
			:task_destroy => /^task_destroy/,
			:task_get_all => /^task_get_all/,

			# Event
			:event_register => /^event_register/,
			:event_unregister => /^event_unregister/,
			:event_next => /^event_next/,
			:event_get_current_id => /^event_get_current_id/,

			# VM
			:vm_snapshot => /^VM_snapshot/,
			:vm_clone => /^VM_clone/,
			:vm_copy => /^VM_copy/,
			:vm_start => /^VM_start/,
			:vm_start_on => /^VM_start_on/,
			:vm_pause => /^VM_pause/,
			:vm_unpause => /^VM_unpause/,
			:vm_suspend => /^VM_suspend/,
			:vm_resume => /^VM_resume/,
			:vm_clean_shutdown => /^VM_clean_shutdown/,
			:vm_clean_reboot => /^VM_clean_reboot/,
			:vm_hard_showdown => /^VM_hard_shutdown/,
			:vm_pool_migrate => /^VM_pool_migrate/,
			:vm_get_possible_hosts => /^VM_get_possible_hosts/,
			:vm_assert_agile => /^VM_assert_agile/,
			:vm_get_uuid => /^VM_get_uuid/,
			:vm_get_powerstate => /^VM_get_powerstate/,
			:vm_get_name_label => /^VM_name_label/,
			:vm_get_resident_on => /^VM_get_resident_on/,
			:vm_get_all => /^VM_get_all/
	}

	# Access the Session ID
	attr_reader :session, :xenserver 

	# Access and set session attributes
	attr_accessor :uri, :user, :password

	# Initialize with Server URI
	def initialize(uri)
		@uri = uri
		@xenserver = SELF_SSL::XMLRPC_Client.new2(@uri)
	end

	# Initialize with JSON config
	class << self
		def new_with_config(config)
			config = JSON.parse(File.read(config))["xenserver"]
			if config.nil?
				raise XenApiConfigError, "malformed config"
			end
			
			@password = config["password"]
			@user = config["user"]
			@uri = config["uri"]
			if @password.nil? || @user.nil? || @uri.nil?
				raise XenApiConfigError, "missing uri, user, or password"
			end

			s = self.new(@uri)
			s.login_with_password(@user, @password)
			return s
		end
	end

	# Since methods are just forwarded to the Server with params they don't have to be implemented itself
	# but via responding to method_missing in the correct form
	def method_missing(method, *args, &block)
		RPC_METHODS.each do |m|
			if method.to_s =~ m.last
				return xenapi_request(method, *args)
			end
		end
		# Call super class method missing
		super
	end

	# If methods are only implemented via method_missing the responds to is not working correctly anymore 
	# therefor it needs to be updated with the correct methods to be called
	
	def respond_to?(method)
		# Check if any RPC methods match the call
		RPC_METHODS.each do |m|
			return true if method.to_s =~ m.last 
		end
		# Call super class responds_to?
		super
	end

	# Declare a XenAPI request to be only called by object itself
	private
	
	def xenapi_request(method, *params)
		# Catch login method
		if method.to_s =~ RPC_METHODS[:login]
			return login(method, *params)
		end

		if method.to_s =~ RPC_METHODS[:logout]
			return logout(method)
		end
	
		# Pass method to server
		# First part of method name is the class, so _ got to be replace by a .
		method = method.to_s
		method.sub!(/_/, ".")
		
		# Check if we are logged in
		raise XenApiError, "not logged in" unless @session 

		# Call Server with method passed
		res = @xenserver.call(method, @session, *params)
		if res["Status"] == "Success"
			# return the result value passed back via XMLRPC
			return res["Value"]
		else
			# get the error if one occurs
			raise XenApiError, res["ErrorDescription"][0]
		end
		
	end
	
	# Login Method needs to save the session cookie for further requests so it 
	# does not have to be passed every single call
	def login(method, *params)
		# Use saved passwords if nothing is passed
		if params.empty?
			params << @user
			params << @password
		else 
			# save password and user for quicker reloggon
			@user = params[0]
			@password = params[1]
		end

		res =  @xenserver.call("session.#{method}", *params)
		
		if res["Status"] == "Success"
			@session = res["Value"]
			return @session
		else
			raise XenApiError, res["ErrorDescription"][0]
		end
	end

	# Logout needs to clear the session cookie saved by login
	def logout(method)
		# Check if logged on, else session should be nil
		unless @session.nil?
			res = @xenserver.call("session.#{method}", @session)
		else 
			# If not logged in logout will always be successful (common sense)
			return true
		end

		# Check if logout was Successful and clear session if so
		if res["Status"] == "Success"
			@session = nil
			return true
		else
			raise XenApiError, res["ErrorDescription"][0]
		end
	end

end
