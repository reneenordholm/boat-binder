import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sendInvitation",
    "passwordField",
    "invitationPasswordHelp",
    "manualPasswordHelp",
    "passwordSection",
  ]

  connect() {
    this.refreshInvitationFields()
  }

  refreshInvitationFields() {
    if (!this.hasSendInvitationTarget) return

    const inviting = this.sendInvitationTarget.checked

    this.passwordFieldTargets.forEach((field) => {
      field.disabled = inviting
      if (inviting) field.value = ""
    })

    this.passwordSectionTarget.classList.toggle("opacity-75", inviting)
    this.invitationPasswordHelpTarget.classList.toggle("hidden", !inviting)
    this.manualPasswordHelpTarget.classList.toggle("hidden", inviting)
  }
}
