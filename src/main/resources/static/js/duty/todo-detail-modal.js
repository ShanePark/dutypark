const todoDetailMethods = {
    enterEditMode() {
        const modal = document.getElementById("todo-details-modal");
        this.originalTodoTitle = modal.querySelector('.todo-title').value;
        this.originalTodoContent = modal.querySelector('.todo-content').value;
        this.editTodoMode = true;
    },
    cancelEdit() {
        const modal = document.getElementById("todo-details-modal");
        modal.querySelector('.todo-title').value = this.originalTodoTitle;
        modal.querySelector('.todo-content').value = this.originalTodoContent;
        this.editTodoMode = false;
    },
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
                title: '저장되었습니다.',
                showConfirmButton: false,
                timer: sweetAlTimer
            });
            app.editTodoMode = false;
            app.loadTodos();
        });
    },
    completeTodo() {
        const app = this;
        const modal = document.getElementById("todo-details-modal");
        const todoId = modal.getAttribute('data-id');

        fetch(`/api/todos/${todoId}/complete`, {
            method: 'PATCH',
        }).then(response => {
            if (!response.ok) {
                Swal.fire({
                    icon: 'error',
                    title: '할 일 완료 처리에 실패했습니다.',
                    showConfirmButton: false,
                    timer: sweetAlTimer
                });
                return null;
            }
            return response.json();
        }).then(data => {
            if (!data) {
                return;
            }
            Swal.fire({
                icon: 'success',
                title: '할 일이 완료되었습니다.',
                showConfirmButton: false,
                timer: sweetAlTimer
            });
            app.selectedTodoStatus = data.status;
            app.loadTodos();
            $('#todo-details-modal').modal('hide');
        });
    },
    reopenTodo() {
        const app = this;
        const modal = document.getElementById("todo-details-modal");
        const todoId = modal.getAttribute('data-id');

        fetch(`/api/todos/${todoId}/reopen`, {
            method: 'PATCH',
        }).then(response => {
            if (!response.ok) {
                Swal.fire({
                    icon: 'error',
                    title: '할 일 진행중 변경에 실패했습니다.',
                    showConfirmButton: false,
                    timer: sweetAlTimer
                });
                return null;
            }
            return response.json();
        }).then(data => {
            if (!data) {
                return;
            }
            Swal.fire({
                icon: 'success',
                title: '할 일이 재오픈 되었습니다.',
                showConfirmButton: false,
                timer: sweetAlTimer
            });
            app.selectedTodoStatus = data.status;
            app.loadTodos();
            $('#todo-details-modal').modal('hide');
        });
    },
    deleteTodo() {
        const app = this;
        const modal = document.getElementById("todo-details-modal");
        const todoId = modal.getAttribute('data-id');

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
        });
    },
}
