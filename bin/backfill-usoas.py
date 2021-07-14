#!/usr/bin/env python
#pylint: disable=missing-module-docstring,missing-function-docstring,invalid-name,missing-class-docstring

import argparse
import logging
import os

from dotenv import load_dotenv
import psycopg2
import psycopg2.extras
import psycopg2.sql
from tqdm import tqdm


class UsoaBackfiller():
    def __init__(self):
        self._dbh = psycopg2.connect(
            dbname=os.getenv('POSTGRES_DB'),
            user=os.getenv('POSTGRES_USER'),
            password=os.getenv('POSTGRES_PASSWD'),
            host=os.getenv('POSTGRES_HOST'),
            cursor_factory=psycopg2.extras.RealDictCursor
        )

    def backfill(self):
        sql = psycopg2.sql.SQL(
            """
            SELECT
                DISTINCT(parent_gsscode)
            FROM
                ons_chd
            WHERE
                parent_gsscode LIKE 'ONS:GSS:W03%' AND status = 'live';
            """
        )
        with self._dbh.cursor() as cur:
            cur.execute(sql)
            logging.info('starting backfill for %d USOAs', cur.rowcount)
            progress = tqdm(desc='USOAs', total=cur.rowcount, unit=' places')
            while True:
                row = cur.fetchone()
                if not row:
                    break

                progress.update(n=1)
                id_ = row['parent_gsscode']
                # logging.info('starting backfill for %s', id_)

                with self._dbh:
                    with self._dbh.cursor() as mcur:
                        msql = psycopg2.sql.SQL(
                            """
                            INSERT INTO places(id,name,name_cym,entity,entity_name,entity_abbr,geom)
                                SELECT c.gsscode, c.name, c.name_cym, c.entitycd, r.name AS entity_name,
                                    r.abbr, (
                                        SELECT ST_Multi(ST_Union(geom)) AS geom
                                        FROM places
                                        WHERE id IN (
                                            SELECT gsscode
                                            FROM ons_chd
                                            WHERE parent_gsscode = %s))
                                FROM ons_chd c, ons_rgc r
                            WHERE c.gsscode = %s AND r.entity = c.entitycd;
                            """
                        )
                        mcur.execute(msql, (id_, id_))

            progress.close()

        sql = psycopg2.sql.SQL(
            """
            UPDATE places
                SET lng = ST_X(ST_PointOnSurface(geom)),
                lat = ST_Y(ST_PointOnSurface(geom))
            WHERE entity = 'ONS:GSS:W03';
            """
        )
        logging.info('finalising long/lat backfill')
        with self._dbh:
            with self._dbh.cursor() as cur:
                cur.execute(sql)


def main():
    parser = argparse.ArgumentParser(
        prog='backfill-usoas',
        description='Generate and build missing Upper Layer Super Output Areas'
    )
    parser.add_argument(
        '-v',
        '--verbose',
        dest='verbose',
        action='store_true',
        help='enable chatty logging; default is false',
        default=False
    )
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    load_dotenv()
    backfiller = UsoaBackfiller()
    backfiller.backfill()


if __name__ == '__main__':
    main()
