UPDATE ons_chd
    SET gsscode=(SELECT 'ONS:GSS:' || gsscode),
    parent_gsscode=(SELECT 'ONS:GSS:' || parent_gsscode),
    entitycd=(SELECT 'ONS:GSS:' || entitycd);

CREATE INDEX IF NOT EXISTS ons_chd_gsscode_idx ON ons_chd USING btree(gsscode);
CREATE INDEX IF NOT EXISTS ons_chd_status_idx ON ons_chd USING btree(status);

UPDATE ons_rgc
    SET entity=(SELECT 'ONS:GSS:' || entity),
    first_code=(SELECT 'ONS:GSS:' || first_code),
    last_code=(SELECT 'ONS:GSS:' || last_code),
    reserved_code=(SELECT 'ONS:GSS:' || reserved_code);

UPDATE ons_rgc
    SET change_date=null WHERE change_date = 'n/a';
UPDATE ons_rgc
    SET related=null WHERE related = 'n/a';
UPDATE ons_rgc
    SET status=lower(status);
ALTER TABLE ons_rgc
    ALTER COLUMN change_date TYPE date USING change_date::date,
    ALTER COLUMN intro_date TYPE date USING intro_date::date,
    ALTER COLUMN start_date TYPE date USING start_date::date;

ALTER TABLE os_gla
  	ADD COLUMN lng double precision,
  	ADD COLUMN lat double precision;

UPDATE os_gla
 	SET lng = ST_X(ST_PointOnSurface(geom)),
 	lat = ST_Y(ST_PointOnSurface(geom));
				 
ALTER TABLE ons_spc
	ADD COLUMN lng double precision,
	ADD COLUMN lat double precision;
	
UPDATE ons_spc
 	SET lng = ST_X(ST_PointOnSurface(geom)),
 	lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE ons_spr
	ADD COLUMN lng double precision,
	ADD COLUMN lat double precision;
	
UPDATE ons_spr
 	SET lng = ST_X(ST_PointOnSurface(geom)),
 	lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE ons_oa
	ADD COLUMN lng double precision,
	ADD COLUMN lat double precision;
	
UPDATE ons_oa
 	SET lng = ST_X(ST_PointOnSurface(geom)),
 	lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE osni_lgd
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE osni_lgd
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE osni_dea
    ADD COLUMN gsscode character varying,
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE osni_dea
    SET gsscode=(SELECT gsscode FROM ons_chd WHERE entitycd = 'ONS:GSS:N10' AND name = osni_dea.name),
    lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE osni_ctry
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE osni_ctry
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE osni_wd
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE osni_wd
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

-- ALTER TABLE os_ced
-- 	ADD COLUMN id character(9),
-- 	ADD COLUMN lng double precision,
-- 	ADD COLUMN lat double precision;

-- UPDATE os_ced
--     SET id=(SELECT DISTINCT ons_wd_lad_cty_ced.ced_id FROM ons_wd_lad_cty_ced WHERE ons_wd_lad_cty_ced.ced_name = name LIMIT 1),
--     lng = ST_X(ST_PointOnSurface(geom)),
--     lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE nrs_oa
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE nrs_oa
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE mgs_dz
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE mgs_dz
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE mgs_iz
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE mgs_iz
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE nisra_oa
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE nisra_oa
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE nisra_sa
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE nisra_sa
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

ALTER TABLE nisra_soa
    ADD COLUMN lng double precision,
    ADD COLUMN lat double precision;

UPDATE nisra_soa
    SET lng = ST_X(ST_PointOnSurface(geom)),
    lat = ST_Y(ST_PointOnSurface(geom));

