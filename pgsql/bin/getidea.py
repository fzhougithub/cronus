#!/usr/bin/env python3

import argparse
import json

from pglast import parse_sql
from pglast.visitors import Visitor


class SkeletonVisitor(Visitor):

    AGG_FUNCS = {
        "count",
        "sum",
        "avg",
        "min",
        "max",
        "string_agg",
        "array_agg",
        "json_agg",
        "jsonb_agg"
    }

    def __init__(self):

        self.result = {
            "tables": set(),
            "columns": set(),

            "aggregates": set(),
            "functions": set(),

            "aggregate_columns": [],
            "group_by_columns": set(),
            "filter_columns": set(),

            "join_details": [],
            "join_count": 0,

            "group_by": False,
            "order_by": False,
            "where": False,
            "having": False
        }

    def _extract_column_ref(self, node):

        try:

            if not hasattr(node, "fields"):
                return None

            parts = []

            for f in node.fields:

                if hasattr(f, "sval"):
                    parts.append(str(f.sval))

            if parts:
                return ".".join(parts)

        except Exception:
            pass

        return None

    def visit_RangeVar(self, ancestors, node):

        try:
            if node.relname:
                self.result["tables"].add(node.relname)
        except Exception:
            pass

    def visit_ColumnRef(self, ancestors, node):

        col = self._extract_column_ref(node)

        if col:
            self.result["columns"].add(col)

    def visit_JoinExpr(self, ancestors, node):

        self.result["join_count"] += 1

        detail = {
            "join_type": str(getattr(node, "jointype", "UNKNOWN")),
            "left_column": None,
            "right_column": None
        }

        try:

            if hasattr(node, "quals") and node.quals:

                cols = []

                self._collect_join_columns(
                    node.quals,
                    cols
                )

                if len(cols) >= 2:
                    detail["left_column"] = cols[0]
                    detail["right_column"] = cols[1]

        except Exception:
            pass

        self.result["join_details"].append(detail)

    def _collect_join_columns(self, node, cols):

        try:

            if node is None:
                return

            col = self._extract_column_ref(node)

            if col:
                cols.append(col)

            for attr in node:

                try:

                    child = getattr(node, attr)

                    if isinstance(child, (list, tuple)):

                        for item in child:
                            self._collect_join_columns(
                                item,
                                cols
                            )
                    else:

                        self._collect_join_columns(
                            child,
                            cols
                        )

                except Exception:
                    pass

        except Exception:
            pass

    def visit_FuncCall(self, ancestors, node):

        try:

            names = []

            for item in node.funcname:

                if hasattr(item, "sval"):
                    names.append(item.sval)

            func_name = ".".join(names).lower()

            self.result["functions"].add(func_name)

            if func_name in self.AGG_FUNCS:

                self.result["aggregates"].add(func_name)

                if node.args:

                    for arg in node.args:

                        col = self._extract_column_ref(arg)

                        if col:

                            self.result[
                                "aggregate_columns"
                            ].append({
                                "function": func_name,
                                "column": col
                            })

        except Exception:
            pass

    def visit_SelectStmt(self, ancestors, node):

        if node.whereClause:

            self.result["where"] = True

            self._collect_filter_columns(
                node.whereClause
            )

        if node.groupClause:

            self.result["group_by"] = True

            for item in node.groupClause:

                col = self._extract_column_ref(item)

                if col:
                    self.result[
                        "group_by_columns"
                    ].add(col)

        if node.sortClause:
            self.result["order_by"] = True

        if node.havingClause:
            self.result["having"] = True

    def _walk_node(self, node):

        if node is None:
            return

        col = self._extract_column_ref(node)

        if col:
            yield col

        try:

            for attr in node:

                try:

                    child = getattr(node, attr)

                    if isinstance(child, (list, tuple)):

                        for item in child:
                            yield from self._walk_node(item)

                    else:
                        yield from self._walk_node(child)

                except Exception:
                    pass

        except Exception:
            pass

    def _collect_filter_columns(self, where_node):

        for col in self._walk_node(where_node):
            self.result["filter_columns"].add(col)


def build_skeleton(sql_text):

    tree = parse_sql(sql_text)

    visitor = SkeletonVisitor()
    visitor(tree)

    r = visitor.result

    return {

        "tables": sorted(r["tables"]),
        "columns": sorted(r["columns"]),

        "aggregates": sorted(r["aggregates"]),
        "functions": sorted(r["functions"]),

        "aggregate_columns":
            r["aggregate_columns"],

        "group_by_columns":
            sorted(r["group_by_columns"]),

        "filter_columns":
            sorted(r["filter_columns"]),

        "join_details":
            r["join_details"],

        "join_count":
            r["join_count"],

        "group_by":
            r["group_by"],

        "order_by":
            r["order_by"],

        "where":
            r["where"],

        "having":
            r["having"]
    }


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "sql_file",
        help="SQL file"
    )

    parser.add_argument(
        "-o",
        "--output"
    )

    args = parser.parse_args()

    with open(args.sql_file, "r") as f:
        sql = f.read()

    result = build_skeleton(sql)

    if args.output:

        with open(args.output, "w") as f:
            json.dump(
                result,
                f,
                indent=2
            )

    else:

        print(
            json.dumps(
                result,
                indent=2
            )
        )


if __name__ == "__main__":
    main()
