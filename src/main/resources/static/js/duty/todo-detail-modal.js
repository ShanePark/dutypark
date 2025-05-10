const todoDetailMethods = {
  updateTodo() {
    const app = this;
    const modal = document.getElementById("todo-details-modal");
    const todoId = modal.getAttribute('data-id');
    const title = modal.querySelector('.todo-title').value;
    const content = modal.querySelector('.todo-content').value;

    if (!title) {
      app.alertTodoTitle();
      return;
    }

    fetch(`/api/todos/${todoId}`, {
      method: 'PUT',
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
          title: '할 일 수정에 실패했습니다.',
          showConfirmButton: false,
          timer: sweetAlTimer
        });
        return;
      }
      Swal.fire({
        icon: 'success',
        title: '할 일이 수정되었습니다.',
        showConfirmButton: false,
        timer: sweetAlTimer
      });
      app.loadTodos();
      $('#todo-details-modal').modal('hide');
    });
  },
  deleteTodo() {
    const app = this;
    const modal = document.getElementById("todo-details-modal");
    const todoId = modal.getAttribute('data-id');

    fetch(`/api/todos/${todoId}`, {
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
      app.loadTodos();
      $('#todo-details-modal').modal('hide');
    });
  },
}
