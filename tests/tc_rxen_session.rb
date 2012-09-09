#!/usr/bin/env ruby

require "test_helper"
require "test/unit"
require "rxen"
require "net/http"
require "net/https"
require "json"

class SessionTest < Test::Unit::TestCase

	# define Server config file
	SERVER_CONFIG = "test_server.json"
	MALFORMED_CONFIG = "test_malformed.json"
	MALFORMED_CONFIG_USER = "test_malformed_user.json"

	# Methods that can be called on the xensession at the moment
	METHODS = [
			:session_change_password,	
			:session_get_all_subject_identifiers,
			:session_logout_subject_identifier,
			:session_get_uuid,
			:session_get_this_user,
			:session_get_this_host,
			:session_get_last_active,
			:session_get_pool,
			:session_get_other_config,
			:session_set_other_config,
			:task_create,
			:task_destroy,
			:task_get_all,
			:event_register,
			:event_unregister,
			:event_next,
			:event_get_current_id,
			:VM_snapshot,
			:VM_clone,
			:VM_copy,
			:VM_start,
			:VM_start_on,
			:VM_pause,
			:VM_unpause,
			:VM_suspend,
			:VM_resume,
			:VM_clean_shutdown,
			:VM_clean_reboot,
			:VM_hard_shutdown,
			:VM_pool_migrate,
			:VM_get_possible_hosts,
			:VM_assert_agile,
			:VM_get_uuid,
			:VM_get_powerstate,
			:VM_name_label,
			:VM_get_resident_on,
			:VM_get_all
	]

	# Methods used for testing do to them being non blocking and do not require specific order
	# of execution
	METHODS_TEST_SAVE = {
			:session_get_all_subject_identifiers => [],
			:task_get_all => [],
			:event_register => ["task"],
			:event_unregister => ["task"],
			:event_get_current_id => [],
			:VM_get_all => []
	}

	# Setup 
	def setup
		config = JSON.parse(File.read(SERVER_CONFIG))["xenserver"]
		@serveruri = config["uri"]
		@user = config["user"]
		@password = config["password"]
		@xensession = Session.new(@serveruri)
	end

	def test_login
		# Check if Session responds to login
		assert_respond_to(@xensession, :login_with_password)

		# Check if login works
		assert_nothing_raised(XenApiError) do
			@xensession.login_with_password(@user, @password)
		end
		assert_not_nil( @xensession.session )
		assert_not_nil( @xensession.user )
		assert_not_nil( @xensession.password )

		# Login credentials should be saved, and not be required again
		assert_nothing_raised(XenApiError) do
			@xensession.login_with_password()
		end
		
		# Check if login fails with wrong password and username, overwriting 
		# saved ones
		assert_raise(XenApiError) do
			@xensession.login_with_password("toor", "12345")
		end
		assert_equal( @xensession.user, "toor" )
		assert_equal( @xensession.password, "12345" )

	end

	def test_new_with_config
		test_session = nil
		assert_nothing_raised(XenApiConfigError) do
			test_session = Session.new_with_config(SERVER_CONFIG)
		end

		assert_not_nil( test_session.session )

		assert_raises(XenApiConfigError) do
			Session.new_with_config(MALFORMED_CONFIG)
		end
		
		assert_raises(XenApiConfigError) do
			Session.new_with_config(MALFORMED_CONFIG_USER)
		end
	end

	def test_logout
		# Check if Session responds to logout
		assert_respond_to(@xensession, :logout)

		# Logout should always be successful if not logged in
		assert_equal(true, @xensession.logout())

		# Login first
		@xensession.login_with_password(@user, @password)
		
		# Check if we are logged in
		assert_not_nil( @xensession.session )
		
		# Logout
		assert_nothing_raised(XenApiError) do
			@xensession.logout()
		end
		assert_nil( @xensession.session )
	end

	def test_respond_to_method
		# Check to see if we are responding to correct methods
		METHODS.each do |m|
			assert_respond_to( @xensession, m ) 
		end
	end

	def test_method_basic_function
		# Check if no methods defined throw an error
		# Start by loggin in
		assert_nothing_raised(XenApiError) {@xensession.login_with_password(@user, @password)}
		
		# Methods able to call
		METHODS_TEST_SAVE.each do |m|
			assert_nothing_raised(XenApiError) do
				if m[1].empty?
					@xensession.send(m[0])
				else
					@xensession.send(m[0], m[1])
				end
			end
		end

		# End by loggin out
		assert_nothing_raised(XenApiError) {@xensession.logout()}
	end

	def test_method_call_deep
		# We should not be able to call a method unless we are logged in
		assert_raise(XenApiError) do
			@xensession.VM_get_all()
		end

		# Login now 
		@xensession.login_with_password(@user, @password)

		# Method should run fine now
		assert_nothing_raised(XenApiError) do
			@xensession.VM_get_all()
		end
	end
	
end
