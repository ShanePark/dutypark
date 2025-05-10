const monthControlMethods = {
  addMonth(month) {
    const newDate = new Date(this.year, this.month - 1 + month);
    this.year = newDate.getFullYear();
    this.month = newDate.getMonth() + 1;
    this.searchDay = null;
  },
  today() {
    const today = new Date();
    this.year = today.getFullYear();
    this.month = today.getMonth() + 1;
    this.searchDay = null;
    this.monthSelector.year = this.year;
    this.closeDropdown();
  },
  selectMonth(month) {
    this.year = this.monthSelector.year;
    this.month = month;
    this.searchDay = null;
    this.closeDropdown();
  },
}
