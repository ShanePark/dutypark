const todoListMethods = {
  addTodoModal() {
    const modal = document.getElementById('add-todo-modal');
    modal.querySelector('.todo-title').value = '';
    modal.querySelector('.todo-content').value = '';
    $('#add-todo-modal').modal('show');
  },
  showTodoDetails(todo) {
    const modal = document.getElementById("todo-details-modal");
    modal.querySelector(".todo-title").value = todo.title;
    modal.querySelector(".todo-content").value = todo.content;
    const dateElement = modal.querySelector(".todo-date");
    dateElement.innerHTML = '';
    const createdSpan = document.createElement('span');
    createdSpan.textContent = `등록 ${todo.createdDate}`;
    dateElement.appendChild(createdSpan);
    if (todo.completedDate) {
      dateElement.appendChild(document.createElement('br'));
      const completedSpan = document.createElement('span');
      completedSpan.textContent = `완료 ${todo.completedDate}`;
      dateElement.appendChild(completedSpan);
    }
    $('#todo-details-modal').modal('show');

    modal.setAttribute('data-id', todo.id);
    this.selectedTodoStatus = todo.status;
    this.editTodoMode = false;
  }
  ,
  loadTodos() {
    this.todosLoading = true;
    Promise.all([
      fetch('/api/todos'),
      fetch('/api/todos/completed')
    ])
      .then(responses => {
        const hasError = responses.some(response => !response.ok);
        if (hasError) {
          Swal.fire({
            icon: 'error',
            title: '할 일 목록을 불러오는데 실패했습니다.',
            showConfirmButton: false,
            timer: sweetAlTimer
          });
          throw new Error('Failed to load todos');
        }
        return Promise.all(responses.map(response => response.json()));
      })
      .then(([activeTodos, completedTodos]) => {
        this.todos = activeTodos;
        this.completedTodos = completedTodos;
        this.todosLoading = false;
        this.$nextTick(() => {
          this.initSortable();
        });
      })
      .catch(() => {
        // Error already handled with alert.
        this.todosLoading = false;
      });
  }
  ,
  openTodoOverview() {
    $('#todo-overview-modal').modal('show');
  }
  ,
  formatDateTime(dateString) {
    if (!dateString) {
      return '';
    }
    return dateString.replace('T', ' ');
  }
  ,
  formatSimpleDate(dateString) {
    if (!dateString) {
      return '';
    }
    return dateString.split('T')[0];
  }
  ,
  formatFullDateTime(dateString) {
    if (!dateString) {
      return '';
    }
    return dateString.replace('T', ' ');
  }
  ,
  toggleOverviewFilter(type) {
    if (type === 'all') {
      this.todoOverviewFilters.active = true;
      this.todoOverviewFilters.completed = true;
      return;
    }

    if (type === 'active') {
      this.todoOverviewFilters.active = !this.todoOverviewFilters.active;
    }
    if (type === 'completed') {
      this.todoOverviewFilters.completed = !this.todoOverviewFilters.completed;
    }
  }
  ,
  reopenTodoFromOverview(todo) {
    fetch(`/api/todos/${todo.id}/reopen`, {
      method: 'PATCH',
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '할 일 진행중 변경에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return;
      }
      Swal.fire({
        icon: 'success',
        title: '할 일이 진행중으로 변경되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      this.loadTodos();
    });
  }
  ,
  completeTodoFromOverview(todo) {
    fetch(`/api/todos/${todo.id}/complete`, {
      method: 'PATCH',
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '할 일 완료 처리에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return;
      }
      Swal.fire({
        icon: 'success',
        title: '할 일이 완료되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      this.loadTodos();
    });
  }
  ,
  deleteTodoFromOverview(todo) {
    Swal.fire({
      icon: 'warning',
      title: '할 일을 삭제할까요?',
      showCancelButton: true,
      confirmButtonText: '삭제',
      cancelButtonText: '취소',
      confirmButtonColor: '#dc3545'
    }).then(result => {
      if (!result.isConfirmed) {
        return;
      }
      fetch(`/api/todos/${todo.id}`, {
        method: 'DELETE',
      }).then(response => {
        if (!response.ok) {
          Swal.fire({
            icon: 'error',
            title: '할 일 삭제에 실패했습니다.',
            showConfirmButton: false,
            timer: sweetAlTimer
          });
          return;
        }
        Swal.fire({
          icon: 'success',
          title: '할 일이 삭제되었습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        this.loadTodos();
      });
    });
  }
  ,
  updatePosition() {
    const todoListElement = document.getElementById('todo-list');
    const todoItems = todoListElement.querySelectorAll('.todo-item');
    const todoIds = Array.from(todoItems).map(todo => todo.getAttribute('data-id'));
    fetch('/api/todos/position', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(todoIds)
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '할 일 순서 변경에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
      }
    });
  }
  ,
}
