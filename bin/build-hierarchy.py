#!/usr/bin/env python
#pylint: disable=missing-module-docstring,missing-function-docstring,invalid-name,missing-class-docstring

from functools import lru_cache
import json
import logging
import os

from dotenv import load_dotenv
import psycopg2
import psycopg2.extras
import psycopg2.sql
from tqdm import tqdm

TREE_SEPARATOR = '.'
TREE_DELIMITER = '_'
LABEL_DELIMITER = ':'


def label_formatter(labels):
    return labels.replace(LABEL_DELIMITER, TREE_DELIMITER)


def label_parser(labels):
    return labels.replace(TREE_DELIMITER, LABEL_DELIMITER)


def label_exploder(labels):
    return label_parser(labels).split(TREE_SEPARATOR)


class HierarchyBuilder():
    def __init__(self, config, parents):
        self._dbh = psycopg2.connect(
            dbname=os.getenv('POSTGRES_DB'),
            user=os.getenv('POSTGRES_USER'),
            password=os.getenv('POSTGRES_PASSWD'),
            host=os.getenv('POSTGRES_HOST'),
            cursor_factory=psycopg2.extras.RealDictCursor
        )
        self._config = config
        self._parents = parents
        self._hierarchy = {}

    def build(self):
        sql = psycopg2.sql.SQL(
            """
            UPDATE places
                SET path_admin=%(path_admin)s,
                    path_census=%(path_census)s,
                    path_electoral=%(path_electoral)s,
                    tree_admin=%(tree_admin)s,
                    tree_census=%(tree_census)s,
                    tree_electoral=%(tree_electoral)s
                WHERE id = %(id)s;
            """
        )

        logging.info('building %d parent/child hierarchies', len(self._parents))
        progress = tqdm(desc='Places', total=len(self._parents), unit=' places')
        for code, place in self._parents.items():
            progress.update(n=1)
            logging.debug('code: %s', code)
            for tree_type in ['admin', 'census', 'electoral']:
                tree, labels = self._walk_tree(place, tree_type)
                tree_key = 'tree_%s' % tree_type
                path_key = 'path_%s' % tree_type

                if not tree:
                    tree = None
                place[tree_key] = labels

                if labels:
                    labels = label_formatter('.'.join(labels))
                else:
                    labels = None
                place[path_key] = labels

            if not code in self._hierarchy:
                self._hierarchy[code] = place
            else:
                logging.error('%s: duplicate place id found', code)
                break

            with self._dbh:
                with self._dbh.cursor() as cur:
                    cur.execute(
                        sql,
                        {
                            'path_admin': place['path_admin'],
                            'path_census': place['path_census'],
                            'path_electoral': place['path_electoral'],
                            'tree_admin': place['tree_admin'],
                            'tree_census': place['tree_census'],
                            'tree_electoral': place['tree_electoral'],
                            'id': code
                        }
                    )

        progress.close()
        return self._hierarchy

    @lru_cache(maxsize=300000)
    def _lookup_place(self, code):
        if code in self._parents:
            return self._parents[code]

        return None

    def _walk_tree(self, start, tree_type):
        field = 'parent_%s' % tree_type
        labels = []
        tree = {}
        code = start[field]

        while code:
            place = self._lookup_place(code)
            if place:
                labels.append(code)
                tree[code] = {
                    'id': place['id'],
                    'name': place['name'],
                    'placetype': place['placetype'],
                    'entity': place['entity'],
                    'entity_name': place['entity_name']
                }
                code = place[field]

            else:
                code = None

        return tree, labels


def main():
    parser = argparse.ArgumentParser(
        prog='build-hierarchy',
        description='Build parent/child hierarchy relationships'
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
        type=argparse.FileType('r',
                               encoding='UTF-8'),
        help='Input parent JSON file path',
        default='parents.json'
    )
    parser.add_argument(
        '-o',
        '--output',
        type=argparse.FileType('w',
                               encoding='UTF-8'),
        help='Output parent/child JSON file path',
        default='hierarchy.json'
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
    parents = json.load(args.parents)

    builder = HierarchyBuilder(config, parents)
    hierarchy = builder.build()

    logging.info('serialising %d places to %s', len(hierarchy), args.output.name)
    json.dump(hierarchy, args.output, indent=2)


if __name__ == '__main__':
    import argparse

    main()
