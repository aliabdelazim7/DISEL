-- إضافة حقل الخصومات لجدول معاملات الموظفين
alter table employee_transactions add column if not exists deductions numeric default 0;
