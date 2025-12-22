#!/usr/bin/env python3
import os
import aws_cdk as cdk
from stacks.full_stack import XyzFullStack

app = cdk.App()

name_prefix = app.node.try_get_context("namePrefix") or "xyz-dev"

XyzFullStack(
    app,
    "XyzFullStack",
    name_prefix=name_prefix,
    env=cdk.Environment(
        account=os.getenv("CDK_DEFAULT_ACCOUNT"),
        region=os.getenv("CDK_DEFAULT_REGION"),
    ),
)

app.synth()
