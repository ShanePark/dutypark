const otherDutiesMethods = {
  alt: function (friend, event) {
    const isChecked = event.target.checked;
    if (isChecked) {
      this.otherDutiesSelected.push(friend);
    } else {
      const index = this.otherDutiesSelected.indexOf(friend);
      this.otherDutiesSelected.splice(index, 1);
    }
    this.loadOtherDuties();
  },

  loadOtherDuties() {
    this.otherDuties = [];
    if (this.otherDutiesSelected.length === 0) {
      return;
    }
    const params = new URLSearchParams({
      year: this.year,
      month: this.month,
      memberIds: this.otherDutiesSelected.map(friend => friend.id).join(',')
    })
    fetch(`/api/duty/others?${params.toString()}`, {
      method: 'GET',
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '다른 사람의 근무표를 불러오는 데 실패했습니다.',
          showConfirmButton: false,
          timer: 3000
        });
        return;
      }
      return response.json();
    }).then(data => {
      this.otherDuties = data;
    });
  }
  ,
}
