create or replace package test_002_gateway is
/* 
-- Flows for APEX - test_002_gateway.pks
-- 
-- (c) Copyright Oracle Corporation and / or its affiliates, 2022.
--
-- Created  08-Mar-2022   Louis Moreaux, Insum
-- Modified 28-Jun-2022   Richard Allen, Oracle   
-- 
*/
   --%suite(test_gateway)
   --%rollback(manual)

   -- Need to add tests for completing order

   --%test
   procedure exclusive_no_route;

   --%test
   procedure exclusive_default;

   --%test
   procedure exclusive_route_provided;

   --%test
   procedure inclusive_no_route;

   --%test
   procedure inclusive_default;

   --%test
   procedure inclusive_route_provided;

   --%test
   procedure parallel;

   --%test
   procedure event_based;

   --%afterall
   procedure tear_down_tests;
   
end test_002_gateway;