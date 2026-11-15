package example.libraries;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import example.libraries.mysqlservices.IbookService;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*", methods = { RequestMethod.GET, RequestMethod.POST, RequestMethod.PUT , RequestMethod.DELETE })
public class CatalogController {

    @Autowired
    private IbookService service;
    
    public CatalogController() {
    }

    @GetMapping("/getlibros")
    public ResponseEntity<?> GetLibraries() {
        List<Book> booksList = service.GetAll();// new ArrayList<Book>(books.values());
        return new ResponseEntity<List<Book>>(booksList, HttpStatus.OK);
    }

    // Listado paginado: GET /api/libros?page=0&size=20 (size maximo 100)
    @GetMapping("/libros")
    public ResponseEntity<List<Book>> getLibrosPaginados(
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "20") int size) {
        int pagina = Math.max(page, 0);
        int tamano = Math.min(Math.max(size, 1), 100);
        return new ResponseEntity<List<Book>>(service.getPage(pagina, tamano), HttpStatus.OK);
    }

    // Consulta de un libro: GET /api/libro/9790000000001
    @GetMapping("/libro/{isbn}")
    public ResponseEntity<Book> getLibro(@PathVariable("isbn") String isbn) {
        return new ResponseEntity<Book>(service.getByIsbn(isbn), HttpStatus.OK);
    }

//    @PostMapping("/agregarlibro")
//    public ResponseEntity<?> PostLibrary(@RequestParam(value = "titulo") String titulo,
//            @RequestParam(value = "ISBN") String iSBN, @RequestParam(value = "autor") String autor,
//            @RequestParam(value = "resena") String reseña, @RequestParam(value = "valor") String valor,
//            @RequestParam(value = "unidades") Integer unidades) {
//
//        service.Insert(iSBN, titulo, autor, reseña, valor, unidades);
//        return new ResponseEntity<String>("insert OK", HttpStatus.OK);
//    }

    @PostMapping("libro")
    public ResponseEntity<Book> saveBook(@RequestBody Book book) {
        Book bookSaved = service.saveBook(book);
        return new ResponseEntity<Book>(bookSaved, HttpStatus.OK);
    }

    @PutMapping("libro")
    public ResponseEntity<Book> updateBook(@RequestBody Book book) {
        Book bookSaved = service.updateBook(book);
        return new ResponseEntity<Book>(bookSaved, HttpStatus.OK);
    }

    @DeleteMapping("/deletelibro")
    public ResponseEntity<?> PostLibrary(@RequestParam(value = "ISBN") String iSBN) {
        service.Delete(iSBN);
        return new ResponseEntity<String>("delete OK", HttpStatus.OK);
    }

}
