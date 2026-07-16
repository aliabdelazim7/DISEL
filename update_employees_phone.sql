-- إضافة رقم الهاتف لجدول الموظفين
alter table employees add column if not exists phone text;
