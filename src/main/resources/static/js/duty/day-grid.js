// ====== COMPUTES ======
const dDayComputes = {
  calendarWithDuties() {
    return this.calendar.map((day, i) => ({
      calendarDay: day,
      duty: this.duties[i] || {}
    }));
  }
  ,
  calcDday() {
    const app = this;
    return (calendarDay) => {
      const date = new Date(calendarDay.year, calendarDay.month - 1, calendarDay.day);
      const calc = Math.floor((date.getTime() - new Date(app.selectedDday.date).getTime()) / (1000 * 60 * 60 * 24)) + 1;
      return calc < 0 ? 'D' + calc : calc === 0 ? 'D-Day' : 'D+' + (calc + 1);
    }
  }
  ,
  printScheduleTime() {
    const app = this;
    return (schedule) => {
      let result = '';
      if (app.shouldDisplayStartTime(schedule)) {
        const startTime = app.formattedTime(schedule.startDateTime);
        result += '(' + startTime;
        if (app.shouldDisplayEndTime(schedule)) {
          const endTime = app.formattedTime(schedule.endDateTime);
          return result + '~' + endTime + ')';
        }
        return result + ')';
      }

      if (app.shouldDisplayEndTime(schedule)) {
        const endTime = app.formattedTime(schedule.endDateTime);
        return result + ' (~' + endTime + ')';
      }
      return result;
    }
  }
  ,
  shouldDisplayEndTime() {
    const app = this;
    return (schedule) => {
      const daysFromStart = schedule.daysFromStart;
      const totalDays = schedule.totalDays;
      const startDateTime = new Date(schedule.startDateTime);
      const endDateTime = new Date(schedule.endDateTime);
      const endHour = endDateTime.getHours().toString().padStart(2, '0');
      const endMinute = endDateTime.getMinutes().toString().padStart(2, '0');
      return (daysFromStart === totalDays)
        && !(endHour === '00' && endMinute === '00')
        && !(totalDays === 1 && app.sameDateTime(startDateTime, endDateTime));
    }
  }
  ,
  shouldDisplayStartTime() {
    return (schedule) => {
      const daysFromStart = schedule.daysFromStart;
      const startDateTime = new Date(schedule.startDateTime);
      const startHour = startDateTime.getHours().toString().padStart(2, '0');
      const startMinute = startDateTime.getMinutes().toString().padStart(2, '0');
      return daysFromStart === 1 && !(startHour === '00' && startMinute === '00');
    }
  }
  ,
  canEdit() {
    return this.isMyCalendar || this.amIManager
  }
  ,
}
// ====== COMPUTES END ======


// ======== METHODS =========
const dayGridMethods = {
  isSearchDay(calendarDay) {
    return calendarDay.year === this.year && calendarDay.month === this.month && calendarDay.day === this.searchDay;
  },
  isHoliday(index) {
    const holidays = this.holidaysByDays[index];
    if (!holidays || holidays.length === 0) {
      return false;
    }
    for (const holiday of holidays) {
      if (holiday.isHoliday)
        return true;
    }
    return false;
  }
  ,
  viewDayDetail(calendarDay, duty, index) {
    const app = this;
    if (app.batchEditMode || !app.canEdit) {
      return;
    }
    app.isCreateScheduleMode = false;
    $('#detail-view-modal').modal('show');
    app.detailView = calendarDay;
    app.detailView.duty = duty;
    app.detailView.index = index;
    app.detailView.scheduleStartDiffCount = app.schedulesByDays[index].length;
    for (const schedule of app.schedulesByDays[index]) {
      if (app.dutyAndDateTimeSame(calendarDay, schedule.startDateTime)) {
        app.detailView.scheduleStartDiffCount--;
      }
    }
    app.resetCreateSchedule();
  }
  ,
  isToday(calendarDay) {
    const today = new Date();
    return calendarDay.year === today.getFullYear() && calendarDay.month === today.getMonth() + 1 && calendarDay.day === today.getDate();
  },
  dutyTypeClasses(type, duty) {
    const teamLength = this.team.dutyTypes.length;
    const colClass = (teamLength === 2 || teamLength === 4) ? 'col-md-6' : 'col-md-4';
    return {
      ['BACKGROUND-' + type.color]: true,
      selected: type.id === duty.dutyTypeId,
      [colClass]: true,
    };
  }
  ,
  dutyAndDateTimeSame() {
    return (calendarDay, dateTimeString) => {
      const year = calendarDay.year;
      const month = calendarDay.month - 1;
      const day = calendarDay.day;
      const dateTime = new Date(dateTimeString);
      return year === dateTime.getFullYear() && month === dateTime.getMonth() && day === dateTime.getDate();
    }
  }
  ,
  hasSchedule() {
    return (index) => {
      return this.schedulesByDays[index] && this.schedulesByDays[index].length > 0;
    }
  },
  showDescription(schedule) {
    const description = schedule.description.replace(/\n/g, '<br>');
    Swal.fire({
      title: schedule.content,
      html: description,
      showCloseButton: true,
      showCancelButton: false,
      focusConfirm: false,
      confirmButtonText: '확인',
      confirmButtonColor: '#3085d6',
      customClass: {
        title: 'text-align-left',
        htmlContainer: 'text-align-left'
      }
    });
  }
}
// ======== END METHODS =========
