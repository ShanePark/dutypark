const dutyTableHeaderMethods = {
  showBatchUpdate() {
    const app = this;
    Swal.fire({
      title: '한번에 수정',
      html: `
                              <p>${app.year}년 ${app.month}월의 기본 듀티를 선택해주세요.</p>
                              <p>현재 월의 모든 날짜가 선택한 듀티로 설정됩니다.</p>
                              <p class="bg-warning">클릭시 바로 변경됩니다.</p>
                              <div>
                                  ${app.team.dutyTypes.map(type => `
                                      <button class="btn duty-type BACKGROUND-${type.color}" data-id="${type.id}">
                                          ${type.name}
                                      </button>
                                  `).join('')}
                              </div>`,
      showConfirmButton: false,
      showCancelButton: true,
      cancelButtonText: '취소',
      didOpen: () => {
        const buttons = document.querySelectorAll('.swal2-html-container button');
        buttons.forEach(button => {
          button.addEventListener('click', () => {
            const dutyId = button.getAttribute('data-id');
            this.batchUpdate(dutyId);
            Swal.close();
          });
        });
      }
    });
  },
  batchUpdate(dutyTypeId) {
    const app = this;
    fetch(`/api/duty/batch`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        year: app.year,
        month: app.month,
        dutyTypeId: dutyTypeId,
        memberId: app.memberId,
      })
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '일괄 수정에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return;
      }
      app.loadDuties();
    });
  },
  async uploadBatchFile() {
    const app = this;
    const fileExtensions = app.team.dutyBatchTemplate.fileExtensions;
    const {value: file} = await Swal.fire({
      title: "시간표 파일 업로드",
      input: "file",
      html: "시간표 파일을 업로드해주세요.<br/> 자동으로 파일에 맞춰 시간표를 업데이트 합니다.<br/>파일을 선택하기 전에, 업로드하는 시간표가 현재 선택된 년월에 맞는지 꼭 확인해주세요.",
      inputAttributes: {
        "accept": fileExtensions.join(','),
        "aria-label": "시간표 파일을 업로드해주세요.",
      },
      confirmButtonText: "등록",
    });
    if (!file)
      return;
    const formData = new FormData();
    formData.append("file", file);
    formData.append("year", app.year);
    formData.append("month", app.month);
    formData.append("memberId", app.memberId);
    fetch("/api/duty_batch", {
      method: "POST",
      body: formData,
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: "error",
          title: "파일 업로드에 실패했습니다.",
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return;
      }
      return response.json()
    }).then(data => {
      if (!data.result) {
        Swal.fire({
          icon: "error",
          title: "시간표 파일 업로드 실패",
          text: data.errorMessage,
        });
        return;
      }
      const workingDays = data.workingDays;
      const offDays = data.offDays;
      const startDate = data.startDate;
      const endDate = data.endDate;
      swal.fire({
        icon: "success",
        title: "시간표 적용 완료",
        html: `시간표가 업로드 되었습니다.<br/>[${startDate}] ~ [${endDate}]<br/> 총 ${workingDays + offDays}일 중 근무일은 ${workingDays}, 휴무일은 ${offDays}일 입니다.`,
        confirmButtonText: "확인",
      });
      app.loadDuties();
    });
  },
}
