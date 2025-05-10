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
    modal.querySelector(".todo-date").textContent = todo.createdDate;
    $('#todo-details-modal').modal('show');

    modal.setAttribute('data-id', todo.id);
    this.editTodoMode = false;
  }
  ,
  loadTodos() {
    fetch('/api/todos')
      .then(response => {
        if (!response.ok) {
          Swal.fire({
            icon: 'error',
            title: '할 일 목록을 불러오는데 실패했습니다.',
            showConfirmButton: false,
            timer: sweetAlTimer
          });
          return;
        }
        return response.json();
      }).then(data => {
      this.todos = data;
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
