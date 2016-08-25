require 'rails_helper'

RSpec.describe 'signing in 2fa', type: :feature do
  Warden.test_mode!

  let!(:root_node) { Fabricate(:root_node) }
  let!(:otp_user) { Fabricate(:user, bypass_tfa: false) }
  let!(:totp_user) { Fabricate(:totp_user, bypass_tfa: false) }

  let!(:valid_authenticate_request) {
    stub_request(:post, Rails.configuration.sms_authenticate_url).
        with(:body => {"client_id"=>"", "client_secret"=>"", "grant_type"=>"client_credentials", "scope"=>"SMS"},
             :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).
        to_return(:status => 200, :body => '{"access_token":"somereallyspecialtoken", "expires_in":"3599"}', :headers => {})
  }

  let!(:send_sms_request) {
    stub_request(:post, "https://smsapi.com/send").
        with(:headers => {'Authorization'=>'Bearer somereallyspecialtoken', 'Content-Type'=>'application/json'}).
        to_return(:status => 200, :body => "", :headers => {})
  }

  describe 'two factor authentication as otp user' do
    before {
      login_as(otp_user)
      # Need to navigate somewhere to trigger 2fa login for tests
      visit root_path
    }

    it 'should ask for code input' do
      expect(page).to have_content('Enter the code that was sent to you')
      expect(page).to have_field('Enter 6 digit code')
    end


    it 'should provide a resend link' do
      expect(page).to have_link('Resend now')
    end

    context 'with the incorrect code' do
      before {
        fill_in('Enter 6 digit code', with: '000000')
        click_button('Verify')
      }

      it 'should return an error' do
        expect(page).to have_content('Attempt failed.')
        expect(page).to have_field('Enter 6 digit code')
      end
    end


    context 'with the correct code' do

      before {
        fill_in('Enter 6 digit code', with: User.find(otp_user).direct_otp)
        click_button('Verify')
      }

      it 'should redirect to root' do
        expect(current_path).to eq(root_path)
        expect(page).to have_link('Sign out')

        expect(send_sms_request).to have_been_requested
      end
    end
  end

  describe 'two factor authentication as totp user' do
    before {
      login_as(totp_user)
      # Need to navigate somewhere to trigger 2fa login for tests
      visit root_path
    }

    it 'should ask for authenticator code' do
      expect(page).to have_field('Enter 6 digit code')
      expect(page).to have_content('Enter the code from your authenticator app')
    end

    it 'should provide a link to an sms code' do
      expect(page).to have_link('Send me a code instead')
    end

    context 'with the wrong code' do
      before {
        fill_in('Enter 6 digit code', with: 'notacode')
        click_button('Verify')
      }


      it 'should return an error' do
        expect(page).to have_content('Attempt failed.')
        expect(page).to have_field('Enter 6 digit code')
      end
    end

    context 'with the correct code' do
      before {
        # Code defined in fabricators/users.rb
        fill_in('Enter 6 digit code', with: ROTP::TOTP.new('averysecretkey').now)
        click_button('Verify')
      }

      it 'shoould login user' do
        expect(current_path).to eq(root_path)
        expect(page).to have_content(totp_user.email)
      end
    end

    context 'with sms requested instead' do
      before {
        click_link('Send me a code instead')
      }

      it 'ask for sms code input' do
        expect(page).to have_content('Enter the code that was sent to you')
      end

      context 'with the correct code' do
        before {
          fill_in('Enter 6 digit code', with: User.find(totp_user).direct_otp)
          click_button('Verify')
        }


        it 'should login user' do
          expect(current_path).to eq(root_path)
          expect(page).to have_content(totp_user.email)
        end
      end
    end
  end
end

