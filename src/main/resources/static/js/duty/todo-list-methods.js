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
          this.initOverviewSortable();
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
    this.$nextTick(() => {
      this.initOverviewSortable();
    });
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
    this.$nextTick(() => {
      this.initOverviewSortable();
    });
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
    if (!todoListElement) {
      return;
    }
    const todoItems = todoListElement.querySelectorAll('.todo-item');
    const todoIds = Array.from(todoItems)
      .map(todo => todo.getAttribute('data-id'))
      .filter(Boolean);
    if (todoIds.length === 0) {
      return;
    }
    this.reorderTodosByIds(todoIds);
    this.saveTodoOrder(todoIds);
    this.$nextTick(() => {
      this.initOverviewSortable();
    });
  }
  ,
  initOverviewSortable() {
    const overviewList = document.getElementById('todo-overview-list');
    if (!overviewList) {
      return;
    }
    const existingSortable = Sortable.get(overviewList);
    if (existingSortable) {
      existingSortable.option('handle', '.handle');
      existingSortable.option('draggable', '.todo-overview-item-active');
      existingSortable.option('animation', 150);
      existingSortable.option('onEnd', () => {
        this.updateOverviewPosition();
      });
      return;
    }
    new Sortable(overviewList, {
      animation: 150,
      draggable: '.todo-overview-item-active',
      handle: '.handle',
      onEnd: () => {
        this.updateOverviewPosition();
      },
    });
  }
  ,
  updateOverviewPosition() {
    const overviewList = document.getElementById('todo-overview-list');
    if (!overviewList) {
      return;
    }
    const activeItems = overviewList.querySelectorAll('.todo-overview-item-active');
    const todoIds = Array.from(activeItems)
      .map(item => item.getAttribute('data-id'))
      .filter(Boolean);
    if (todoIds.length === 0) {
      return;
    }
    this.reorderTodosByIds(todoIds);
    this.saveTodoOrder(todoIds);
    this.$nextTick(() => {
      this.initSortable();
      this.initOverviewSortable();
    });
  }
  ,
  reorderTodosByIds(todoIds) {
    const todoMap = new Map(this.todos.map(todo => [todo.id, todo]));
    const idSet = new Set(todoIds);
    const reordered = todoIds
      .map(id => todoMap.get(id))
      .filter(Boolean);
    const remaining = this.todos.filter(todo => !idSet.has(todo.id));
    this.todos = [...reordered, ...remaining];
  }
  ,
  saveTodoOrder(todoIds) {
    if (!todoIds || todoIds.length === 0) {
      return;
    }
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
