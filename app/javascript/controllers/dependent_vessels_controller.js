import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["account", "asset"]

  connect() {
    this.filter()
  }

  filter() {
    const accountId = this.accountTarget.value

    this.assetTarget.querySelectorAll("optgroup").forEach((group) => {
      const matches = accountId === "" || group.dataset.accountId === accountId
      group.hidden = !matches
      group.disabled = !matches
    })

    this.assetTarget.querySelectorAll("option[data-account-id]").forEach((option) => {
      const matches = accountId === "" || option.dataset.accountId === accountId
      option.hidden = !matches
      option.disabled = !matches
    })

    const selectedOption = this.assetTarget.selectedOptions[0]
    if (selectedOption?.disabled) {
      this.assetTarget.value = ""
    }
  }

  syncAccount() {
    const selectedOption = this.assetTarget.selectedOptions[0]
    const accountId = selectedOption?.dataset.accountId

    if (accountId) {
      this.accountTarget.value = accountId
    }

    this.filter()
  }
}
