@echo off
scpcli scf cloud-function code set --cloud_function_id 7577fdd93b9349cd9e11e0299df5192d --content "$(type 'D:\scpv2\advance_cloudnative\serverless\cloud_functions\orders-function.js')"