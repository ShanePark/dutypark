function loadApp(memberId, teamId, loginMemberId, memberName, year, month, searchDay) {
  const app = new Vue({
      el: '.duty-vue',
      data: {
        memberId: memberId,
        teamId: teamId,
        loginMemberId: loginMemberId,
        memberName: memberName,
        isMyCalendar: loginMemberId === memberId,
        year: year,
        month: month,
        searchDay: searchDay,
        amIManager: false,
        calendar: [],
        duties: [],
        schedulesByDays: [],
        holidaysByDays: [],
        team: {},
        hasTeam: false,
        dDays: [],
        selectedDday: null,
        dDaysReady: false,
        detailView: {
          duty: {
            'dutyColor': '',
            'dutyType': '',
          },
          'id': '',
          'month': '',
          'year': '',
          'day': '',
        },
        batchEditMode: false,
        isCreateScheduleMode: false,
        monthSelector: {
          year: year,
        },
        schedule_content_max_length: schedule_content_max_length,
        createSchedule: {
          id: '',
          content: '',
          description: '',
          startDateTime: '',
          startDate: '',
          startTime: '',
          startDateTimeOld: '',
          endDateTime: '',
          visibility: 'FAMILY',
          attachmentSessionId: null,
          sessionCreationPromise: null,
          uploadedAttachments: [],
          attachmentProgress: {},
          attachmentUploadMeta: {},
          attachmentUploadTicker: 0,
        },
        newTodo: {
          title: '',
          content: '',
          attachmentSessionId: null,
          sessionCreationPromise: null,
          uploadedAttachments: [],
          attachmentProgress: {},
          attachmentUploadMeta: {},
          attachmentUploadTicker: 0,
          uploadTickerInterval: null,
        },
        editTodo: {
          id: '',
          title: '',
          content: '',
          attachmentSessionId: null,
          sessionCreationPromise: null,
          uploadedAttachments: [],
          attachmentProgress: {},
          attachmentUploadMeta: {},
          attachmentUploadTicker: 0,
          uploadTickerInterval: null,
        },
        friends: [],
        todoAddUppyInstance: null,
        todoAddFileInputListener: null,
        todoDetailUppyInstance: null,
        todoDetailFileInputListener: null,
        todos: [],
        completedTodos: [],
        todosLoading: false,
        editTodoMode: false,
        selectedTodoAttachments: [],
        selectedTodoStatus: 'ACTIVE',
        originalTodoTitle: '',
        originalTodoContent: '',
        todoOverviewFilters: {
          active: true,
          completed: false,
        },
        loadDutyPromise: null,
        searchQuery: '',
        searchResults: [],
        MAX_OTHER_DUTIES: 3,
        otherDutiesSelected: [],
        otherDuties: [],
        showMyDuties: false,
      }, mounted() {
        if (teamId) {
          this.hasTeam = true;
          this.loadTeam();
          this.loadDuties();
        }
        this.loadCalendar();
        this.loadSchedule();
        this.loadHolidays();
        this.loadFriends();
       this.loadDDays();
       this.checkAmIManager();
       if (this.isMyCalendar) {
         this.loadTodos();
       }
       this.initSortable();
       this.setupModalCloseHandler();
        this.setupTodoAttachmentHandlers();
      }, computed: {
        ...dDayComputes,
        ...searchResultComputes,
        filteredOverviewTodos: {
          get() {
            const items = [];
            if (this.todoOverviewFilters.active) {
              items.push(...this.todos);
            }
            if (this.todoOverviewFilters.completed) {
              items.push(...this.completedTodos);
            }
            return items;
          }
        },
        currentCalendar: {
          get() {
            const day = this.searchDay || -1;
            return `${this.year}-${this.month.toString().padStart(2, '0')}-${day}`;
          },
        },
        combinedYearMonth: {
          get() {
            return `${this.year}-${this.month.toString().padStart(2, '0')}`;
          }
        },
        isAttachmentUploading: {
          get() {
            return Object.keys(this.createSchedule.attachmentUploadMeta || {}).length > 0;
          }
        },
        attachmentUploadSummary: {
          get() {
            const ticker = this.createSchedule.attachmentUploadTicker;
            const uploads = Object.values(this.createSchedule.attachmentUploadMeta || {});
            if (uploads.length === 0) {
              return null;
            }
            const totalBytes = uploads.reduce((sum, meta) => sum + (meta.bytesTotal || 0), 0);
            const uploadedBytes = uploads.reduce((sum, meta) => sum + (meta.bytesUploaded || 0), 0);
            const startedAt = uploads.reduce((earliest, meta) => {
              if (!meta.startedAt) {
                return earliest;
              }
              if (earliest === null) {
                return meta.startedAt;
              }
              return Math.min(earliest, meta.startedAt);
            }, null);
            const now = ticker || Date.now();
            const elapsedMs = startedAt ? Math.max(now - startedAt, 0) : 0;
            const elapsedSeconds = elapsedMs / 1000;
            const progress = totalBytes > 0 ? Math.min(uploadedBytes / totalBytes, 1) : 0;
            const speed = elapsedSeconds > 0 ? uploadedBytes / elapsedSeconds : 0;
            const remainingBytes = Math.max(totalBytes - uploadedBytes, 0);
            const remainingSeconds = speed > 0 ? remainingBytes / speed : null;
            return {
              totalBytes,
              uploadedBytes,
              remainingBytes,
              elapsedSeconds,
              remainingSeconds,
              speedBytesPerSec: speed,
              progressPercent: Math.min(Math.round(progress * 100), 100),
              activeUploads: uploads.length,
            };
          }
        },
        canSearch: {
          get() {
            return this.isMyCalendar || this.amIManager;
          }
        },
        searchPlaceholder: {
          get() {
            if (this.isMyCalendar)
              return '검색';
            return this.memberName;
          }
        }
      },
      watch: {
        currentCalendar() {
          this.loadCalendar();
          this.loadDuties();
          this.loadSchedule();
          this.loadHolidays();
          this.loadDDays();
          const currentUrl = new URL(window.location.href);
          currentUrl.searchParams.set('year', app.year);
          currentUrl.searchParams.set('month', app.month);
          currentUrl.searchParams.set('day', app.searchDay);
          if (!app.searchDay) {
            currentUrl.searchParams.delete('day');
          }
          window.history.replaceState(null, '', currentUrl.toString());
          app.monthSelector.year = app.year;
        }
        ,
        'createSchedule.startTime': function () {
          this.updateStartDateTime();
        },
        'createSchedule.startDate': function () {
          this.updateStartDateTime();
        },
      },
      methods: {
        ...todoListMethods,
        ...todoAddMethods,
        ...todoDetailMethods,
        ...monthControlMethods,
        ...dutyTableHeaderMethods,
        ...dayGridMethods,
        ...searchResultMethods,
        ...detailViewMethods,
        ...dDayMethods,
        ...formatMethods,
        ...otherDutiesMethods,
        setupTodoAttachmentHandlers() {
          const addTodoModal = document.getElementById('add-todo-modal');
          if (addTodoModal) {
            addTodoModal.addEventListener('hidden.bs.modal', () => {
              this.cancelAddTodo(true);
            });
          }
          const todoDetailsModal = document.getElementById('todo-details-modal');
          if (todoDetailsModal) {
            todoDetailsModal.addEventListener('hidden.bs.modal', () => {
              this.exitTodoDetailAttachments(true);
            });
          }
        },
        updateStartDateTime() {
          app.createSchedule.startDateTime = app.createSchedule.startDate + 'T' + app.createSchedule.startTime;
          if (
            app.createSchedule.startDateTimeOld === app.createSchedule.endDateTime ||
            app.createSchedule.startDateTime > app.createSchedule.endDateTime
          ) {
            app.createSchedule.endDateTime = app.createSchedule.startDateTime;
          }
          app.createSchedule.startDateTimeOld = app.createSchedule.startDateTime;
        },
        closeDropdown() {
          const dropdownElement = document.querySelector('.dropdown-menu');
          const dropdownInstance = new bootstrap.Dropdown(dropdownElement, {autoClose: true});
          dropdownInstance.hide();
        },
        loadCalendar() {
          fetch(`/api/calendar?year=${this.year}&month=${this.month}`)
            .then(response => response.json())
            .then(data => {
              this.calendar = data;
            });
        },
        loadDuties() {
          this.loadDutyPromise = new Promise((resolve) => {
            $.ajax({
              url: '/api/duty',
              type: 'GET',
              data: {
                memberId: memberId,
                year: this.year,
                month: this.month,
              },
              success: (data) => {
                this.duties = data;
                resolve();
              }
            })
          });
          this.loadOtherDuties();
        },
        setDutyCounts() {
          let offCnt = new Date(app.year, app.month, 0).getDate();
          this.team.dutyTypes.forEach(dutyType => {
            this.$set(dutyType, 'cnt', 0);
          });
          this.duties.forEach(duty => {
            if (duty.month !== this.month) {
              return;
            }
            this.team.dutyTypes.forEach(dutyType => {
              if (dutyType.id && dutyType.name === duty.dutyType) {
                this.$set(dutyType, 'cnt', dutyType.cnt + 1);
                offCnt--;
              }
            });
          });
          this.team.dutyTypes.forEach(dutyType => {
            if (!dutyType.id) {
              this.$set(dutyType, 'cnt', offCnt);
            }
          });
        },
        loadSchedule() {
          $.ajax({
            url: '/api/schedules',
            type: 'GET',
            data: {
              memberId: memberId,
              year: this.year,
              month: this.month,
            },
            success: (data) => {
              this.schedulesByDays = data;
            }
          })
        }
        ,
        loadTeam() {
          fetch(`/api/teams/${teamId}`)
            .then(response => response.json())
            .then(data => {
              this.team = data;
              this.loadDutyPromise.then(() => {
                this.setDutyCounts();
              });
            })
        },
        resetCreateSchedule() {
          const defaultDateTime = app.formattedDateTime(app.detailView);
          app.stopAttachmentUploadTicker();
          app.createSchedule = {
            id: '',
            content: '',
            description: '',
            startDateTime: defaultDateTime,
            startDate: app.formattedDate(app.detailView.year, app.detailView.month, app.detailView.day),
            startTime: '00:00',
            startDateTimeOld: defaultDateTime,
            endDateTime: defaultDateTime,
            visibility: 'FAMILY',
            attachmentSessionId: null,
            sessionCreationPromise: null,
            uploadedAttachments: [],
            attachmentProgress: {},
            attachmentUploadMeta: {},
            attachmentUploadTicker: 0,
          };
        }
        ,
        changeDutyType(duty, type) {
          $.ajax({
            url: '/api/duty/change',
            type: 'PUT',
            data: JSON.stringify({
              year: duty.year,
              month: duty.month,
              day: duty.day,
              dutyTypeId: type.id,
              memberId: memberId,
            }),
            contentType: 'application/json',
            success: (data) => {
              app.$set(duty, 'dutyType', type.name);
              app.$set(duty, 'dutyColor', type.color);
              app.setDutyCounts();
            },
            fail: (data) => {
              Swal.fire({
                icon: 'error',
                title: '저장에 실패했습니다.',
                showConfirmButton: false,
                timer: sweetAlTimer
              });
            }
          })
        },
        async loadHolidays() {
          const response = await fetch(`/api/holidays?year=${this.year}&month=${this.month}`);
          if (!response.ok) {
            Swal.fire({
              icon: 'error',
              title: '휴무일 정보를 불러오는데 실패했습니다.',
              showConfirmButton: false,
              timer: sweetAlTimer
            });
            return;
          }
          this.holidaysByDays = await response.json();
        }
        ,
        loadFriends() {
          if (!loginMemberId || !this.isMyCalendar) {
            return;
          }
          fetch('/api/friends')
            .then(async response => {
              if (!response.ok) {
                Swal.fire({
                  icon: 'error',
                  title: '친구 목록을 불러오는데 실패했습니다.',
                  showConfirmButton: false,
                  timer: sweetAlTimer
                });
                return;
              }
              this.friends = await response.json();
            });
        },
        addTag(scheduleId, friendId) {
          fetch(`/api/schedules/${scheduleId}/tags/${friendId}`, {
            method: 'POST',
          }).then(response => {
            if (!response.ok) {
              Swal.fire({
                icon: 'error',
                title: '태그 추가에 실패했습니다.',
                showConfirmButton: false,
                timer: sweetAlTimer
              });
              return;
            }
            app.loadSchedule();
          });
        }
        ,
        untag(schedule, friendId) {
          if (!this.isMyCalendar) {
            return;
          }
          fetch(`/api/schedules/${schedule.id}/tags/${friendId}`, {
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
        ,
        initSortable() {
          let todoListElement = document.getElementById('todo-list');
          if (todoListElement) {
            const existingSortable = Sortable.get(todoListElement);
            if (existingSortable) {
              return;
            }
            new Sortable(todoListElement, {
              animation: 150,
              draggable: ".todo-item",
              handle: '.handle',
              ghostClass: 'sortable-ghost',
              fallbackClass: 'sortable-fallback',
              chosenClass: 'sortable-chosen',
              fallbackOnBody: true,
              forceFallback: true,
              onEnd: (evt) => {
                app.updatePosition();
              },
            });
          }
        },
        checkAmIManager() {
          if (!this.loginMemberId)
            return;
          fetch(`/api/members/${memberId}/canManage`)
            .then(response => {
              if (!response.ok) {
                Swal.fire({
                  icon: 'error',
                  title: '관리자 권한 확인에 실패했습니다.',
                  showConfirmButton: false,
                  timer: sweetAlTimer
                });
                return;
              }
              return response.json();
            }).then(data => {
            app.amIManager = data;
          });
        },
        sliceText(str, maxlength) {
          if (str.length <= maxlength) {
            return str;
          }
          return str.slice(0, maxlength);
        },
        setupModalCloseHandler() {
          const modal = document.getElementById('detail-view-modal');
          if (modal) {
            $(modal).on('hidden.bs.modal', async () => {
              if (this.isCreateScheduleMode && this.createSchedule.attachmentSessionId) {
                try {
                  await fetch(`/api/attachments/sessions/${this.createSchedule.attachmentSessionId}`, {
                    method: 'DELETE'
                  });
                } catch (error) {
                  console.warn('Failed to discard attachment session on modal close:', error);
                }
                this.cleanupAttachmentUploader();
                this.isCreateScheduleMode = false;
              }
            });
          }
        }
      } // end methods
    }
  )
}
