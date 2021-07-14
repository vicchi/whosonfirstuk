#!/usr/bin/env python
#pylint: disable=missing-module-docstring,missing-function-docstring,invalid-name,missing-class-docstring

import json
import logging
import os
import re

from dotenv import load_dotenv
import psycopg2
import psycopg2.extras
import psycopg2.sql
from tqdm import tqdm
from tqdm.contrib.logging import logging_redirect_tqdm


class ParentBuilder():
    def __init__(self, config):
        self._hierarchy = {}
        self._dbh = psycopg2.connect(
            dbname=os.getenv('POSTGRES_DB'),
            user=os.getenv('POSTGRES_USER'),
            password=os.getenv('POSTGRES_PASSWD'),
            host=os.getenv('POSTGRES_HOST'),
            cursor_factory=psycopg2.extras.RealDictCursor
        )
        self._config = config

    def build(self):
        self._hierarchy = {}
        sql = psycopg2.sql.SQL(
            """
            SELECT distinct(entity),entity_name,entity_abbr FROM places ORDER BY entity DESC;
            """
        )

        with logging_redirect_tqdm():
            with self._dbh.cursor() as cur:
                cur.execute(sql)
                progress = tqdm(desc='Placetypes', total=cur.rowcount, position=0, unit=' types')
                while True:
                    row = cur.fetchone()
                    if not row:
                        break

                    progress.update(n=1)
                    entity = row['entity']
                    entity_name = row['entity_name']
                    if not entity in self._config['mappings']:
                        logging.warning('no mapping for entity %s (%s)', entity, entity_name)
                        continue

                    logging.debug('starting %s (%s)', entity, entity_name)
                    self._build_entity(row)

                progress.close()

        self._hierarchy = dict(sorted(self._hierarchy.items(), reverse=True))
        logging.debug('updating %d places', len(self._hierarchy.items()))

        sql = psycopg2.sql.SQL(
            """
            UPDATE places
                SET placetype=%(placetype)s,
                    parent_admin=%(parent_admin)s,
                    parent_electoral=%(parent_electoral)s,
                    parent_census=%(parent_census)s
                WHERE id=%(place_id)s;
            """
        )

        with self._dbh:
            with self._dbh.cursor() as cur:
                for code, entry in tqdm(iterable=self._hierarchy.items(), desc='Update', unit=' places'):
                    cur.execute(
                        sql,
                        {
                            'placetype': entry['placetype'],
                            'parent_admin': entry['parent_admin'],
                            'parent_census': entry['parent_census'],
                            'parent_electoral': entry['parent_electoral'],
                            'place_id': code
                        }
                    )

        return self._hierarchy

    def _get_change_record(self, code):
        sql = psycopg2.sql.SQL(
            """
            SELECT gsscode,name,parent_gsscode,status
                FROM ons_chd
                WHERE gsscode = %s
                    AND status = 'live';
            """
        )
        with self._dbh.cursor() as cur:
            cur.execute(sql, (code,))
            if cur.rowcount:
                row = cur.fetchone()
                return row

        return None

    def _build_entity(self, record):
        entity = record['entity']

        sql = psycopg2.sql.SQL(
            """
            SELECT id, name, name_cym, entity_name, entity_abbr
	            FROM places
	            WHERE (parent_admin IS NULL OR parent_census IS NULL OR parent_electoral IS NULL) AND
                    entity = %s
                ORDER BY id;
            """
        )

        backfill = False
        entity = record['entity']
        entity_name = record['entity_name']
        entity_abbr = record['entity_abbr']

        with self._dbh.cursor() as cur:
            cur.execute(sql, (entity,))

            if not cur.rowcount:
                backfill = True

            elif not entity in self._config['mappings']:
                logging.error('%s: no configured mapping found!', entity)

            else:
                logging.debug(
                    'building %d empty places for %s (%s)',
                    cur.rowcount,
                    entity,
                    entity_name
                )

                desc = '%s (%s)' % (entity, entity_abbr)
                progress = tqdm(desc=desc, total=cur.rowcount, position=1, unit=' places')
                while True:
                    row = cur.fetchone()
                    if not row:
                        break

                    progress.update(n=1)
                    code = row['id']

                    logging.debug('starting %s: %s', code, row['name'])

                    history = self._get_change_record(code)

                    place = {
                        'id': code,
                        'placetype': self._config['mappings'][entity]['placetype'],
                        'parent_admin': None,
                        'parent_electoral': None,
                        'parent_census': None,
                        'name': self._sanitise_name(code,
                                                    row['name']),
                        'name_alt': row['name_cym'],
                        'entity': entity,
                        'entity_name': row['entity_name']
                    }

                    if entity in self._config['countries']:
                        logging.debug('skipping parent for country %s', code)

                    else:
                        for placetype in self._config['mappings'][entity]['parents']:
                            parent_key = 'parent_%s' % placetype
                            mappings = self._config['mappings'][entity]['parents'][placetype]
                            if mappings and history:
                                parent_candidate = history['parent_gsscode']
                                if parent_candidate:
                                    parent_entity = parent_candidate[0:11]
                                    if parent_entity in mappings:
                                        place[parent_key] = parent_candidate

                        for placetype, mappings in self._config['mappings'][entity]['parents'].items():
                            parent_key = 'parent_%s' % placetype
                            if mappings and not place[parent_key]:
                                if len(mappings) == 1 and mappings[0] in self._config['countries']:
                                    place[parent_key] = self._config['countries'][mappings[0]]

                                else:
                                    parent_code = self._pip_parent(code, mappings)
                                    if parent_code:
                                        place[parent_key] = parent_code

                                    elif code in self._config[
                                        'overrides'] and placetype in self._config['overrides'][code
                                                                                               ]:
                                        place[parent_key] = self._config['overrides'][code][
                                            placetype]

                                    else:
                                        logging.error(
                                            '%s: %s: failed to backfill %s -> %s',
                                            placetype,
                                            code,
                                            parent_key,
                                            ','.join(mappings)
                                        )

                    self._hierarchy[code] = place

                progress.close()

            if backfill:
                sql = psycopg2.sql.SQL(
                    """
                    SELECT id, name, name_cym, entity, entity_name, entity_abbr
	                    FROM places
	                    WHERE (parent_admin IS NULL OR
                            parent_census IS NULL OR
                            parent_electoral IS NULL) AND
                            entity = %s
                        ORDER BY id;
                    """
                )

                with self._dbh.cursor() as cur:
                    cur.execute(sql, (entity,))

                    if not cur.rowcount:
                        logging.error(
                            'backfill found %d places for %s (%s)',
                            cur.rowcount,
                            entity,
                            entity_name
                        )

                    elif not entity in self._config['mappings']:
                        logging.error('%s: no configured mapping found!', entity)

                    else:
                        desc = '%s (%s)' % (entity, entity_abbr)
                        progress = tqdm(desc=desc, total=cur.rowcount, position=1, unit=' places')
                        while True:
                            row = cur.fetchone()
                            if not row:
                                break

                            progress.update(n=1)
                            code = row['id']

                            place = {
                                'id': code,
                                'placetype': self._config['mappings'][entity]['placetype'],
                                'parent_admin': None,
                                'parent_electoral': None,
                                'parent_census': None,
                                'name': self._sanitise_name(code,
                                                            row['name']),
                                'name_alt': row['name_cym'],
                                'entity': entity,
                                'entity_name': row['entity_name'],
                                'hierarchy': []
                            }

                            for placetype, mappings in self._config['mappings'][entity]['parents'].items():
                                parent_key = 'parent_%s' % placetype
                                if mappings and not place[parent_key]:
                                    if len(mappings
                                          ) == 1 and mappings[0] in self._config['countries']:
                                        place[parent_key] = self._config['countries'][mappings[0]]

                                    else:
                                        parent_code = self._pip_parent(code, mappings)
                                        if parent_code:
                                            place[parent_key] = parent_code

                                        elif code in self._config[
                                            'overrides'] and placetype in self._config['overrides'][
                                                code]:
                                            place[parent_key] = self._config['overrides'][code][
                                                placetype]

                                        else:
                                            logging.error(
                                                '%s: %s: failed to backfill %s -> %s',
                                                placetype,
                                                code,
                                                parent_key,
                                                ','.join(mappings)
                                            )

                            self._hierarchy[code] = place

                        progress.close()

    def _pip_parent(self, code, candidate_entities):
        sql = psycopg2.sql.SQL(
            """
            SELECT p.id FROM places s, places p
                WHERE s.id = %s AND
                p.entity IN %s AND
                ST_Within(ST_PointOnSurface(s.geom), p.geom);
            """
        )
        parent_id = None

        with self._dbh.cursor() as cur:
            cur.execute(sql, (code, tuple(candidate_entities)))
            row = cur.fetchone()
            if row:
                parent_id = row['id']

        return parent_id

    def _sanitise_name(self, id_, name):
        entity = id_[0:11]
        if entity in self._config['sanitise']:
            pattern = self._config['sanitise'][entity]['pattern']
            repl = self._config['sanitise'][entity]['repl']
            return re.sub(rf"{pattern}", repl, name)
        else:
            return name


def main():
    parser = argparse.ArgumentParser(
        prog='build-parents',
        description='Build and backfill parent relationships'
    )
    parser.add_argument(
        '-c',
        '--config',
        dest='config',
        type=argparse.FileType('r',
                               encoding='UTF-8'),
        help='Input config JSON file path',
        default='./etc/config.json'
    )
    parser.add_argument(
        '-p',
        '--parents',
        type=argparse.FileType('w',
                               encoding='UTF-8'),
        help='Output parent JSON file path',
        default='parents.json'
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

    config = json.load(args.config)
    builder = ParentBuilder(config)
    parents = builder.build()

    json.dump(parents, args.parents, indent=2)


if __name__ == '__main__':
    import argparse

    main()
