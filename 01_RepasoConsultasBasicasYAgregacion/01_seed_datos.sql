--INSERTAR USUARIOS 
-- DATOS FALTANTES avatar_url , activo , created_at
insert into usuarios (username, email, pais, plan) values 
('Shiriaru', 'shiriaru@app.com', 'Guatemala', 'creator'), 
('Julio', 'julio@app.com', 'México', 'pro'),
('Sebastian', 'sebastian@app.com', 'España', 'free'),
('Angela', 'angela@app.com', 'Guatemala', 'free'); 

-- ACTUALIZAR LOS REGISTROS EXISTENTES CON VALORES FALTANTES.
update usuarios 
set created_at = now()
where created_at is null;

--INSERTAR TUTORIALES
-- DATOS FALTANTES es_publico , fecha_publicacion, created_at 
insert into tutoriales (creador_id, titulo, categoria, duracion_min, likes_count, ejecuciones) values
(1, 'Create Sheet in Word', 'Word', 12, 150, 800),
(1, 'Design Resume in Word', 'Word', 10, 95, 450),
(1, 'Guardar Hoja en Blanco', 'Word', 5, NULL, 120), -- NULL a propósito para practicar
(2, 'Create Video Game in Unreal Engine', 'Unreal Engine', 120, 500, 2100),
(2, 'Build Level in Unreal Engine', 'Unreal Engine', 45, 320, 1500),
(2, 'Create new project in Unreal Engine 5', 'Unreal Engine', 20, 250, 1800),
(3, 'Create Presentation in PowerPoint', 'PowerPoint', 18, 180, 950),
(3, 'Filtrar lineas correctas', 'Excel', 15, 80, 300),
(4, 'Edit Music & Audio Mixes', 'Photoshop', 24, 60, 200),
(4, 'Create Sheet in Word', 'Word', 12, 110, 600); -- duplicado para probar DISTINCT 

-- ACTUALIZAR TODOS LOS TUTORIALES CON VALORES FALTANTES.
update tutoriales									-- TABLA A MODIFICAR 
set created_at = NOW()								-- APLICA EL CAMBIO A ESAS FILAS FILTRADAS
where created_at is null;							-- FILTRAN LAS FILAS QUE CUMPLEN ESA CONDICION

update tutoriales 
set es_publico = true 
where es_publico = false;

--PROGRAMAR ALGUN TUTORIAL 
update tutoriales 
set fecha_publicacion = '2026-08-20 10:00:00-06'
where id = 3;

update tutoriales 
set fecha_publicacion = now()
where fecha_publicacion is null;