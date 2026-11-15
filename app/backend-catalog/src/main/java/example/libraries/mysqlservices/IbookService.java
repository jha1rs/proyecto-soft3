package example.libraries.mysqlservices;

import java.util.List;

import example.libraries.Book;

public interface IbookService {
    public List<Book> GetAll();

    public List<Book> getPage(int page, int size);

    public Book getByIsbn(String isbn);

    public void Delete(String isbn);

    public Book saveBook(Book book);

    public Book updateBook(Book book);

}
