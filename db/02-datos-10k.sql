-- Genera 10.000 libros de prueba dentro de MySQL (sin listar cada INSERT).
-- El mismo script se usa en Docker Compose y en Kubernetes, asi los datos son identicos.
-- ISBN 9790000000001 .. 9790000010000 (no chocan con los libros del script 01).

USE `catalog-library`;

SET SESSION cte_max_recursion_depth = 10001;

INSERT INTO Book (titulo, ISBN, autor, descripcion, valor, unidades)
WITH RECURSIVE seq (n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 10000
)
SELECT
    CONCAT(
        ELT(1 + MOD(n * 7, 12), 'El secreto', 'La sombra', 'El camino', 'La ciudad', 'El ultimo', 'La casa',
            'El jardin', 'La memoria', 'El viaje', 'La voz', 'El silencio', 'La noche'),
        ' ',
        ELT(1 + MOD(n * 11, 12), 'del rio', 'de los andes', 'perdido', 'de cristal', 'olvidado', 'del norte',
            'de papel', 'en llamas', 'del tiempo', 'de la montana', 'sin nombre', 'del mar'),
        ' ', n),
    CONCAT('979', LPAD(n, 10, '0')),
    CONCAT(
        ELT(1 + MOD(n * 3, 16), 'Ana', 'Luis', 'Carlos', 'Maria', 'Jorge', 'Laura', 'Andres', 'Sofia',
            'Diego', 'Valentina', 'Camilo', 'Paula', 'Felipe', 'Daniela', 'Santiago', 'Juliana'),
        ' ',
        ELT(1 + MOD(n * 5, 16), 'Gomez', 'Rodriguez', 'Martinez', 'Lopez', 'Garcia', 'Perez', 'Sanchez', 'Ramirez',
            'Torres', 'Rojas', 'Vargas', 'Moreno', 'Castro', 'Ortiz', 'Suarez', 'Herrera')),
    CONCAT(
        ELT(1 + MOD(n, 8), 'Novela', 'Ensayo', 'Cuento', 'Biografia', 'Manual tecnico', 'Poesia', 'Historia',
            'Divulgacion cientifica'),
        ' numero ', n, ' del catalogo de pruebas de carga'),
    CAST(5 + MOD(n * 13, 116) AS CHAR),
    MOD(n * 17, 101)
FROM seq;
