// Computes
const searchResultComputes = {
  startPage() {
    const currentPage = this.searchResults.pageable.pageNumber + 1;
    return Math.max(1, currentPage - 5);
  },
  endPage() {
    const currentPage = this.searchResults.pageable.pageNumber + 1;
    const totalPages = this.searchResults.totalPages;
    return Math.min(totalPages, currentPage + 5);
  },
  pagesToShow() {
    const pages = [];
    for (let i = this.startPage; i <= this.endPage; i++) {
      pages.push(i);
    }
    return pages;
  }
  ,
}

// Methods
const searchResultMethods = {
  search(page = 0) {
    const app = this;
    $('#search-result-modal').modal('show');
    const query = app.searchQuery;
    fetch(`/api/schedules/${app.memberId}/search?q=${query}&page=${page}`)
      .then((response) => {
        if (!response.ok) {
          Swal.fire({
            icon: 'error',
            title: '검색에 실패했습니다.',
            showConfirmButton: false,
            timer: sweetAlTimer
          });
          return;
        }
        return response.json();
      })
      .then((data) => {
        app.searchResults = data;
      });
  },
  moveToSearch(item) {
    const startDateTime = new Date(item.startDateTime);
    this.year = startDateTime.getFullYear();
    this.month = startDateTime.getMonth() + 1;
    this.searchDay = startDateTime.getDate();
    $('#search-result-modal').modal('hide');
  },
}
