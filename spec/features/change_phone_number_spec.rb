require 'rails_helper'

RSpec.describe 'changing phone number', type: :feature do
  Warden.test_mode!

  let!(:root_node) { Fabricate(:root_node) }
  let!(:user) { Fabricate(:user, bypass_tfa: false, identity_verified_at: Time.now.utc)}
  #let!(:user_totp) { Fabricate(:totp_user, bypass_tfa: false)}

  let(:verify_user) {
    code = User.find(user.id).direct_otp
    fill_in('Enter 6 digit code', with: code)
    click_button('Verify')
  }


  describe 'two_factor_setup#new' do
    before {
      login_as(user)
      visit new_users_two_factor_setup_sms_path
      verify_user
    }

    it { expect(current_path).to eq(new_users_two_factor_setup_sms_path) }

    context 'entering a valid phone number' do
      before {
        fill_in('Phone number', with: '0456789123')
        click_button('Send code')
      }

      it 'shows an input for the code' do
        expect(page).to have_content('A verification code was just sent to the mobile ')
        expect(page).to have_content('**** *** *23')
      end

      it 'does not change the user phone number' do
        expect(User.find(user.id).phone_number).to_not eq('0456789123')
        expect(User.find(user.id).unconfirmed_phone_number).to eq('0456789123')
      end


      context 'entering a valid code' do
        before {
          code = User.find(user.id).unconfirmed_phone_number_otp
          fill_in('Enter 6 digit code', with: code)
          click_button('Verify')
        }

        it 'should change the user phone number' do
          expect(User.find(user.id).phone_number).to eq('0456789123')
          expect(User.find(user.id).unconfirmed_phone_number).to eq(nil)
          expect(page).to have_content('You have successfully verified and saved your phone number')
        end
      end


      context 'requesting a new code' do
        before {
          click_link('Resend verification code')
        }


        it 'should change the otp code' do
          expect(page).to have_content('Please verify your account')
          expect(page).to have_field('Enter 6 digit code')
        end
      end
    end
  end
end