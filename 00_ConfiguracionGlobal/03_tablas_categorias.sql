-- TABLA CATEGORIAS COMO DICCIONARIO EL DASHBOARD FILTRA EN MILISEGUNDOS where categoria_id = 2 (2 es Unreal)
create table if not exists categorias(
    id bigint generated always as identity primary key,
    nombre varchar(50) not null unique,
    slug varchar(50) not null unique,
    color_chip varchar(7),
    created_at timestamptz default  now()
);

-- AGREGAR COLUMNA icono_url
alter table categorias
    add column if not exists icono_url text;

-- AGREGAR COLUMNA orden PARA ORDENAR CHIPS EJ: Word Primero , Unreal Segundo
alter table categorias
-- smallint NUMERO PEQUENO de -32768 a 32767
    add column if not exists orden smallint not null default 100
    check (orden > 0);

-- AGREGAR COLUMNA ACTIVA
alter table categorias
    add column  if not exists activa boolean not null  default  true;

-- AJUSTAR COLUMNA slug PARA INCLUIR EL CHECK
alter table categorias
-- constraint PONERLE NOMBRE A CUALQUIER REGLA , check , unique , foreing key.
    add constraint categorias_slug_check
-- ~ SIGNIFICA CUMPLE ESTA EXPRESION REGULAR?
-- ^ Inicio del texto
-- [a-z0-9] SOLO DEJA LETRAS MINUSCULAS a A z y numeros 0 a 9 , No deja Unreal , á  , _
-- + UNA O MAS VECES LO ANTERIOR [a-z0-9]+ = word, unreal, 3d
-- (-[a-z0-9]+) GUION - SEGUIDO DE LETRAS/NUMEROS Ej: -engine.
-- * CERO O MAS VECES EL GRUPO ANTERIOR PERMITE  word , unreal-engine, super-mario-like-game
-- $ FIN DEL TEXTO.
    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$');

--AJUSTAR COLUMNA color_chip
alter table categorias
    alter column color_chip set not null,
    add constraint categorias_color_chip_check
-- [0-9A-Fa-f] , 0-9 numeros 0-9 , letras A-F mayusculas a-f minusculas , {6} veces lo anterior.
    check ( color_chip ~'^#[0-9A-Fa-f]{6}$' );