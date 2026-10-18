#!/usr/bin/env python3

import json
import sys


def normalize(col):

    if "." in col:
        return col.split(".")[-1]

    return col


def unique(items):

    return sorted(set(items))


#
# Classification
#
def classify_columns(ast):

    group_cols = [
        normalize(c)
        for c in ast.get(
            "group_by_columns",
            []
        )
    ]

    measure_cols = [
        normalize(x["column"])
        for x in ast.get(
            "aggregate_columns",
            []
        )
    ]

    business_dimensions = []
    date_dimensions = []
    identifiers = []
    lookup_attributes = []

    for col in group_cols:

        low = col.lower()

        #
        # identifiers
        #
        if (
            low.endswith("_id")
            and low not in (
                "customer_id",
                "client_id"
            )
        ):
            identifiers.append(col)
            continue

        #
        # dates
        #
        if (
            low.endswith("_dt")
            or low.endswith("_date")
        ):
            date_dimensions.append(col)
            continue

        #
        # lookup descriptions
        #
        if (
            "description" in low
            or low.endswith("_txt")
        ):
            lookup_attributes.append(col)
            continue

        #
        # business dimensions
        #
        business_dimensions.append(col)

    filters = unique(
        normalize(c)
        for c in ast.get(
            "filter_columns",
            []
        )
    )

    measures = []

    for item in ast.get(
        "aggregate_columns",
        []
    ):

        measures.append({
            "column":
                normalize(
                    item["column"]
                ),
            "aggregation":
                item["function"]
        })

    return {

        "business_dimensions":
            unique(
                business_dimensions
            ),

        "date_dimensions":
            unique(
                date_dimensions
            ),

        "identifiers":
            unique(
                identifiers
            ),

        "lookup_attributes":
            unique(
                lookup_attributes
            ),

        "measures":
            measures,

        "filters":
            filters
    }


#
# Join Enrichment Detection
#
def classify_enrichments(ast):

    enrichments = []

    for join in ast.get(
        "join_details",
        []
    ):

        left = join.get(
            "left_column"
        )

        right = join.get(
            "right_column"
        )

        if left and right:

            enrichments.append({
                "fact_key":
                    normalize(left),

                "lookup_key":
                    normalize(right)
            })

    return enrichments


#
# Scoring
#
def calculate_scores(model):

    summary_score = 0
    enrichment_score = 0

    #
    # aggregation exists
    #
    if len(model["measures"]) > 0:
        summary_score += 30

    #
    # business dimensions
    #
    summary_score += (
        len(
            model[
                "business_dimensions"
            ]
        ) * 5
    )

    #
    # dates often aggregate well
    #
    summary_score += (
        len(
            model[
                "date_dimensions"
            ]
        ) * 3
    )

    #
    # claim/order style transaction id
    #
    if model["identifiers"]:
        summary_score -= 25

    enrichment_score += 10

    if model["lookup_attributes"]:
        enrichment_score += (
            len(
                model[
                    "lookup_attributes"
                ]
            ) * 15
        )

    return {
        "summary_score":
            summary_score,

        "enrichment_score":
            enrichment_score
    }


#
# Recommendation
#
def recommend(ast):

    model = classify_columns(ast)

    enrichments = (
        classify_enrichments(ast)
    )

    scores = calculate_scores(
        model
    )

    preferred = (
        "ENRICHED_DATAMART"
        if scores[
            "enrichment_score"
        ] >= scores[
            "summary_score"
        ]
        else "SUMMARY_DATAMART"
    )

    return {

        "preferred_design":
            preferred,

        "scores":
            scores,

        "semantic_model":
            model,

        "enrichment_model":
            enrichments,

        "recommended_datamart": {

            "fact_measures":
                model["measures"],

            "business_dimensions":
                model[
                    "business_dimensions"
                ],

            "date_dimensions":
                model[
                    "date_dimensions"
                ],

            "identifiers":
                model[
                    "identifiers"
                ],

            "lookup_attributes":
                model[
                    "lookup_attributes"
                ],

            "common_filters":
                model["filters"],

            "embedded_dimensions":
                enrichments
        }
    }


def main():

    if len(sys.argv) != 2:

        print(
            "Usage: "
            "python3 suggestion.py file.ast"
        )

        sys.exit(1)

    with open(
        sys.argv[1],
        "r",
        encoding="utf-8"
    ) as f:

        ast = json.load(f)

    result = recommend(ast)

    print(
        json.dumps(
            result,
            indent=2
        )
    )


if __name__ == "__main__":
    main()
