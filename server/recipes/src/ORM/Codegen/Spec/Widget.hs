{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.Widget
  ( widgetModel,
    widgetSchema,
  )
where

import ORM.Codegen.IR

widgetSchema :: Schema
widgetSchema =
  Schema
    { schemaEnums = [],
      schemaModels = [widgetModel],
      schemaIncludes = []
    }

widgetModel :: Model
widgetModel =
  Model
    { modelName = "Widget",
      modelTable = "test_widget",
      modelFields =
        [ pk (withDefault DefaultUuidV4 (uuid "id")),
          column "created_at" (withDefault DefaultNow (timestamptz "createdAt")),
          updatedAt (column "updated_at" (withDefault DefaultNow (timestamptz "updatedAt"))),
          text "name",
          nullable (text "description")
        ],
      modelRelations = []
    }
