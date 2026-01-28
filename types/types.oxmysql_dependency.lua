---@class OxMySQL_Insert
---@field await fun(query: string, params?: table): integer|nil

---@class OxMySQL_Update
---@field await fun(query: string, params?: table): integer|nil

---@class OxMySQL_Query
---@field await fun(query: string, params?: table): table|nil

---@class OxMySQL_Scalar
---@field await fun(query: string, params?: table): string|number|boolean|nil

---@class OxMySQL_Single
---@field await fun(query: string, params?: table): table|nil

---@class OxMySQL_Prepare
---@field await fun(query: string, params?: table|table[]): any

---@class OxMySQL_RawExecute
---@field await fun(query: string, params?: table|table[]): table|nil

---@class OxMySQL_Transaction
---@field await fun(queries: table, values?: table): boolean

---@class OxMySQL
---@field insert fun(query: string, params?: table, cb?: fun(id: integer))|OxMySQL_Insert
---@field update fun(query: string, params?: table, cb?: fun(affectedRows: integer))|OxMySQL_Update
---@field query fun(query: string, params?: table, cb?: fun(result: table|nil))|OxMySQL_Query
---@field scalar fun(query: string, params?: table, cb?: fun(value: string|number|boolean|nil))|OxMySQL_Scalar
---@field single fun(query: string, params?: table, cb?: fun(row: table|nil))|OxMySQL_Single
---@field prepare fun(query: string, params?: table|table[], cb?: fun(result: any))|OxMySQL_Prepare
---@field rawExecute fun(query: string, params?: table|table[], cb?: fun(result: table|nil))|OxMySQL_RawExecute
---@field transaction fun(queries: table, valuesOrCb?: table|fun(success: boolean), cb?: fun(success: boolean))|OxMySQL_Transaction

--- Global MySQL provided by '@oxmysql/lib/MySQL.lua'
---@type OxMySQL
MySQL = MySQL