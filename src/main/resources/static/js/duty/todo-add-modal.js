const todoAddMethods = {
  addTodo() {
    const app = this;
    const addTodoModal = document.getElementById('add-todo-modal');
    const title = addTodoModal.querySelector('.todo-title').value;
    const content = addTodoModal.querySelector('.todo-content').value;
    if (!title) {
      app.alertTodoTitle();
      return;
    }

    fetch('/api/todos', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title: title,
        content: content,
      })
    }).then(response => {
      if (!response.ok) {
        Swal.fire({
          icon: 'error',
          title: '할 일 추가에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return;
      }
      Swal.fire({
        icon: 'success',
        title: '할 일이 추가되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      app.loadTodos();
      $('#add-todo-modal').modal('hide');
    });
  }
  ,
  alertTodoTitle() {
    Swal.fire({
      icon: 'error',
      title: '할일 제목을 입력해주세요.',
      showConfirmButton: false,
      timer: sweetAlTimer
    });
  },
}
