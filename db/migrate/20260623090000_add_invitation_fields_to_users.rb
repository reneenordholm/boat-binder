class AddInvitationFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :invitation_sent_at, :datetime
    add_column :users, :invitation_accepted_at, :datetime
  end
end
