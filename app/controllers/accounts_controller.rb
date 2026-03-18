class AccountsController < ApplicationController
  before_action :set_user

  def show
  end

  def update
    if password_change?
      update_password
    else
      update_account
    end
  end

  def destroy_identity
    identity = @user.identities.find(params[:identity_id])

    if @user.identities.count == 1 && !@user.password_digest.present?
      redirect_to account_path, alert: "Cannot remove your only login method. Please set a password first."
    else
      identity.destroy
      redirect_to account_path, notice: "#{helpers.provider_name(identity.provider)} account has been disconnected."
    end
  end

  def update_avatar
    if params[:avatar].blank?
      render json: { error: "No image provided" }, status: :unprocessable_entity
      return
    end

    @user.avatar.attach(params[:avatar])

    if @user.avatar.attached?
      render json: { success: true }
    else
      render json: { error: "Failed to upload avatar" }, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def password_change?
    params[:password].present? || params[:password_confirmation].present?
  end

  def update_password
    @user.password_confirmation_required = true

    if @user.incidental_password?
      # User created via OAuth - no current password required
      if @user.update(password_params.merge(incidental_password: false))
        redirect_to account_path, notice: "Password has been set."
      else
        redirect_to account_path, alert: @user.errors.full_messages.join(", ")
      end
    elsif params[:current_password].blank?
      redirect_to account_path, alert: "Current password is required."
    elsif !@user.authenticate(params[:current_password])
      redirect_to account_path, alert: "Current password is incorrect."
    elsif @user.update(password_params)
      redirect_to account_path, notice: "Password has been updated."
    else
      redirect_to account_path, alert: @user.errors.full_messages.join(", ")
    end
  end

  def update_account
    if @user.update(account_params)
      redirect_to account_path, notice: "Account has been updated."
    else
      redirect_to account_path, alert: @user.errors.full_messages.join(", ")
    end
  end

  def account_params
    params.permit(:email_address)
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
