const detailViewMethods = {
  scheduleCreateMode() {
    this.resetCreateSchedule();
    this.isCreateScheduleMode = true;
  }
  ,
  cancelCreateSchedule() {
    this.isCreateScheduleMode = false;
  }
  ,
  saveSchedule() {
    const app = this;
    if (!isValidContent(app.createSchedule.content)) {
      return;
    }
    if (!app.isValidDateTime(app.createSchedule.startDateTime, app.createSchedule.endDateTime)) {
      return;
    }
    const addArea = $('#schedule-create-or-edit');
    addArea.waitMe();
    $.ajax({
      url: '/api/schedules',
      type: 'POST',
      data: JSON.stringify({
        id: app.createSchedule.id,
        memberId: app.memberId,
        content: app.createSchedule.content,
        description: app.createSchedule.description,
        startDateTime: toLocalISOString(new Date(app.createSchedule.startDateTime)),
        endDateTime: toLocalISOString(new Date(app.createSchedule.endDateTime)),
        visibility: app.createSchedule.visibility,
      }),
      contentType: 'application/json',
      success: (data) => {
        app.loadSchedule();
        app.isCreateScheduleMode = false;
      },
      error: (data) => {
        Swal.fire({
          icon: 'error',
          title: '저장에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
      }, complete: () => {
        addArea.waitMe('hide');
      }
    })
  }
  ,
  scheduleEditMode(schedule) {
    this.scheduleCreateMode();
    this.createSchedule.id = schedule.id;
    this.createSchedule.content = schedule.content;
    this.createSchedule.description = schedule.description;
    this.createSchedule.startDateTime = schedule.startDateTime;
    this.createSchedule.startDate = schedule.startDateTime.split('T')[0];
    this.createSchedule.startTime = schedule.startDateTime.split('T')[1];
    this.createSchedule.endDateTime = schedule.endDateTime;
    this.createSchedule.visibility = schedule.visibility;
  }
  ,
  swapSchedule(schedule1, schedule2) {
    const app = this;
    $('#detail-view-modal .schedules').waitMe();
    if (!schedule1 || !schedule2 || schedule1 === schedule2) {
      return;
    }
    fetch(`/api/schedules/${schedule1.id}/position?id2=${schedule2.id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json'
      },
    }).then((response) => {
      $('.schedules').waitMe('hide');
      if (response.ok) {
        app.loadSchedule();
      } else {
        Swal.fire({
          icon: 'error',
          title: '순서 변경에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
      }
    });
  }
  ,
  deleteSchedule(schedule) {
    const app = this;
    Swal.fire({
      title: '일정을 삭제하시겠습니까?',
      html: `다음의 일정을 삭제합니다.<br/>[${schedule.content}]<br/> 삭제된 일정은 복구할 수 없습니다.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#d33',
      cancelButtonColor: '#999',
      confirmButtonText: '삭제',
      cancelButtonText: '취소',
    }).then((result) => {
      if (result.isConfirmed) {
        const deleteArea = $('#schedule-' + schedule.id);
        deleteArea.waitMe();
        $.ajax({
          url: '/api/schedules/' + schedule.id,
          type: 'DELETE',
          success: (data) => {
            app.loadSchedule();
          },
          error: (data) => {
            Swal.fire({
              icon: 'error',
              title: '삭제에 실패했습니다.',
              showConfirmButton: false,
              timer: sweetAlTimer
            });
          }, complete: () => {
            deleteArea.waitMe('hide');
          }
        })
      }
    })
  }
  ,
  untagSelf(schedule) {
    const app = this;
    if (!app.isMyCalendar) {
      return;
    }
    const scheduleId = schedule.id;
    const scheduleElement = document.getElementById('schedule-' + scheduleId);
    const scheduleBy = scheduleElement.querySelector('.schedule-tags').querySelector('.schedule-tag').innerText;

    Swal.fire({
      title: '정말로 태그를 제거하시겠습니까?',
      html: `태그된 아래의 일정을 제거합니다.<br/>[${schedule.content}] by${scheduleBy}<br/> 태그를 다시 복구하려면 해당 사용자에게 요청해야합니다.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#d33',
      cancelButtonColor: '#999',
      confirmButtonText: '제거',
      cancelButtonText: '취소',
    }).then((result) => {
      if (result.isConfirmed) {
        fetch(`/api/schedules/${scheduleId}/tags`, {
          method: 'DELETE',
        }).then(response => {
          if (!response.ok) {
            Swal.fire({
              icon: 'error',
              title: '태그 제거에 실패했습니다.',
              showConfirmButton: false,
              timer: sweetAlTimer
            });
            return;
          }
          app.loadSchedule();
        });
      }
    });
  }
  ,
  isDutyType(duty, dutyType) {
    if (duty?.dutyType) {
      return dutyType.name === duty.dutyType
    }
    return !dutyType.id
  }
  ,
  changeDutyTypeWithPopup(duty, type) {
    this.changeDutyType(duty, type);
    Swal.fire({
      icon: 'success',
      title: '변경되었습니다.',
      showConfirmButton: false,
      timer: sweetAlTimer / 3,
    });
  }
  ,
  replaceLineBreaks(text) {
    if (text) {
      return text.replace(/\n/g, '<br>');
    }
    return '';
  }
  ,
}
