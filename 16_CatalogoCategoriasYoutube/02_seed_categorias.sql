-- BORRAR TODOS LOS DATOS ACTUALES DE LA TABLA
-- truncate ELIMINA TODAS LAS FILAS DE LA TABLA DE FORMA RAPIDA
-- restart identity REINICIA EL CONTADOR DE LA COLUMNA.
truncate table categorias restart identity;

INSERT INTO categorias (nombre, slug, color_chip, orden) VALUES
	('Word',           'word',           '#2B579A', 1),
	('Unreal Engine',  'unreal-engine',  '#0E1128', 2),
	('PowerPoint',     'powerpoint',     '#B7472A', 3),
	('Excel',          'excel',          '#217346', 4),
	('Photoshop',      'photoshop',      '#31A8FF', 5),
	('Tools',          'tools',          '#8A2BE2', 6)
ON CONFLICT (nombre) DO NOTHING;