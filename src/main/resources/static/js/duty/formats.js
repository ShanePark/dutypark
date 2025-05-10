const formatMethods = {
  formattedTime(timeString) {
    const dateTime = new Date(timeString);
    const hour = dateTime.getHours() === 12 ? 12 : dateTime.getHours() % 12;
    let minute = '';
    if (dateTime.getMinutes() !== 0) {
      minute = ':' + dateTime.getMinutes().toString().padStart(2, '0');
    }
    return hour + minute + (dateTime.getHours() >= 12 ? 'PM ' : 'AM');
  }
  ,
  formattedDateYMD(dateTimeString) {
    return new Date(dateTimeString).toISOString().split('T')[0].replaceAll('-', '.');
  }
  ,
  formattedDate(year, month, day) {
    month = (month < 10) ? '0' + month : month;
    day = (day < 10) ? '0' + day : day;
    return year + '-' + month + '-' + day;
  }
  ,
  formattedDateTime(detailView) {
    const month = detailView.month.toString().padStart(2, '0');
    const day = detailView.day.toString().padStart(2, '0');
    return `${detailView.year}-${month}-${day}T00:00`;
  }
  ,
  sameDateTime(startDateTime, endDateTime) {
    return startDateTime.getTime() === endDateTime.getTime();
  },
  isValidDateTime(startDateTime, endDateTime) {
    if (!startDateTime || !endDateTime) {
      Swal.fire({
        icon: 'error',
        title: '시작일시와 종료일시를 모두 입력해주세요.',
        confirmButtonText: '확인',
      });
      return false;
    }
    if (new Date(startDateTime) > new Date(endDateTime)) {
      Swal.fire({
        icon: 'error',
        title: '종료일시는 시작일시보다 빠를 수 없습니다.',
        confirmButtonText: '확인',
      });
      return false;
    }
    return true;
  },
}
