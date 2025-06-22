const dDayMethods = {
    loadDDays() {
        const app = this;
        $.ajax({
            url: '/api/dday/' + app.memberId,
            type: 'GET',
            success: (data) => {
                const app = this;
                this.dDays = data;
                const selectedDdayId = parseInt(localStorage.getItem('selectedDday_' + app.memberId));
                for (const dDay of app.dDays) {
                    if (dDay.id === selectedDdayId) {
                        app.selectedDday = dDay;
                    }
                    if (dDay.calc === 0) {
                        dDay.dDayText = 'D-Day';
                    } else if (dDay.calc < 0) {
                        dDay.dDayText = 'D+' + -dDay.calc;
                    } else {
                        dDay.dDayText = 'D-' + dDay.calc;
                    }
                }
                if (this.hasTeam) {
                    this.loadDutyPromise.then(() => {
                        this.checkDDays();
                    });
                }
            }
        })
    }
    ,
    checkDDays() {
        const app = this;
        $('.d-day-schedules').html('');
        for (const dDay of app.dDays) {
            const dayElement = document.getElementById(dDay.date);
            if (dayElement) {
                let scheduleElement = document.createElement('div');
                scheduleElement.classList.add('schedule', 'd-day-schedule');
                scheduleElement.innerHTML = '<i class="bi bi-calendar-check"></i> ' + dDay.title;
                dayElement.querySelector('.d-day-schedules').prepend(scheduleElement);
            }
        }
    },
    dDayToggle(dDay) {
        const app = this;
        if (app.selectedDday === dDay) {
            app.selectedDday = null;
            localStorage.removeItem('selectedDday_' + app.memberId);
        } else {
            app.selectedDday = dDay;
            localStorage.setItem('selectedDday_' + app.memberId, dDay.id);
        }
    }
    ,
    createOrUpdateDday(dDay) {
        const app = this;
        let modal = $('#add_dday_modal').clone();

        const tzOffset = (new Date()).getTimezoneOffset() * 60000; //offset in milliseconds
        modal.find('input[name="date"]').val((new Date(Date.now() - tzOffset)).toISOString().slice(0, 10));
        modal.attr('hidden', false)

        let title = '디데이 추가'
        if (dDay) {
            modal.find('input[name="title"]').val(dDay.title);
            modal.find('input[name="date"]').val(dDay.date);
            modal.find('input[name="isPrivate"]').prop('checked', dDay.isPrivate);
            title = '디데이 수정';
        }

        Swal.fire({
            title: title,
            html: modal,
            cancelButtonText: '닫기',
            confirmButtonText: '저장',
            confirmButtonColor: '#3085d6',
            showCancelButton: true,
            preConfirm: () => {
                const title = Swal.getPopup().querySelector('input[name="title"]').value
                const date = Swal.getPopup().querySelector('input[name="date"]').value
                const isPrivate = Swal.getPopup().querySelector('input[name="isPrivate"]').checked
                if (!title || !date) {
                    Swal.showValidationMessage(`모든 항목을 입력해주세요.`)
                }
                return {
                    id: dDay ? dDay.id : null,
                    title: title,
                    date: date,
                    isPrivate: isPrivate
                }
            },
            didOpen: () => {
                const dateInput = Swal.getPopup().querySelector('input[name="date"]');
                Swal.getPopup().querySelectorAll('.add-days-btn').forEach((btn) => {
                    btn.addEventListener('click', () => {
                        const addDays = parseInt(btn.dataset.days);
                        if (dateInput.value) {
                            const currentDate = new Date(dateInput.value);
                            currentDate.setDate(currentDate.getDate() + addDays);
                            dateInput.value = currentDate.toISOString().slice(0, 10);
                        }
                    });
                });
                Swal.getPopup().querySelector('.reset-day-btn').addEventListener('click', () => {
                    dateInput.value = new Date().toISOString().slice(0, 10);
                });
            }
        }).then((result) => {
            if (result.isConfirmed) {
                modal.waitMe();
                $.ajax({
                    url: '/api/dday',
                    type: 'POST',
                    data: JSON.stringify(result.value),
                    contentType: 'application/json',
                    success: function (response) {
                        Swal.fire({
                            title: '성공',
                            text: '디데이가 저장되었습니다.',
                            icon: 'success',
                            confirmButtonText: '확인'
                        })
                        app.loadDDays();
                    },
                    error: function (error) {
                        Swal.fire({
                            title: '실패',
                            html: '디데이 저장에 실패하였습니다. <br/>에러메시지: ' + error.responseJSON.errors[0].defaultMessage,
                            icon: 'error',
                            confirmButtonText: '확인'
                        })
                    }, complete: function () {
                        modal.waitMe('hide');
                    }
                })
            }
        })
    }
    ,
    removeDday: function (dDay) {
        const app = this;
        Swal.fire({
            title: '디데이 삭제',
            text: '[' + dDay.title + '] ' + rulChecker(dDay.title) + ' 정말로 삭제하시겠습니까?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            confirmButtonText: '삭제',
            cancelButtonText: '취소'
        }).then((result) => {
            if (result.isConfirmed) {
                $('#body').waitMe();
                $.ajax({
                    url: '/api/dday/' + dDay.id,
                    type: 'DELETE',
                    success: function (response) {
                        Swal.fire({
                            title: '성공',
                            text: '디데이가 삭제되었습니다.',
                            icon: 'success',
                            confirmButtonText: '확인'
                        })
                        app.loadDDays();
                    },
                    error: function (error) {
                        Swal.fire({
                            title: '실패',
                            text: '디데이 삭제에 실패하였습니다.',
                            icon: 'error',
                            confirmButtonText: '확인'
                        })
                    },
                    complete: function () {
                        $('#body').waitMe('hide');
                    }
                })
            }
        })
    }
    ,
}
