
/* 
-- Flows for APEX - flow_api_pkg.pkb
-- 
-- (c) Copyright Oracle Corporation and / or its affiliates, 2020-2022.
--
-- Created 2020   Moritz Klein - MT AG  
-- 
*/
create or replace package body flow_api_pkg
as

  function get_dgrm_name
  (
    p_prcs_id in flow_processes.prcs_id%type
  ) return varchar2
  is
    l_dgrm_name flow_diagrams.dgrm_name%type;
  begin

    select dgrm.dgrm_name
      into l_dgrm_name
      from flow_processes prcs
      join flow_diagrams dgrm
        on dgrm.dgrm_id = prcs.prcs_dgrm_id
     where prcs.prcs_id = p_prcs_id
    ;
         
    return l_dgrm_name;
  end get_dgrm_name;

  function flow_create
  (
    pi_dgrm_name in flow_diagrams.dgrm_name%type
  , pi_dgrm_version in flow_diagrams.dgrm_version%type default null
  , pi_prcs_name in flow_processes.prcs_name%type
  ) return flow_processes.prcs_id%type
  as
    l_dgrm_id         flow_diagrams.dgrm_id%type;
    l_dgrm_version    flow_diagrams.dgrm_version%type;
    l_calling_method  flow_types_pkg.t_bpmn_attribute_vc2;
  begin
  
    if pi_dgrm_version is null then
      -- this is the former way of calling the latest release
      l_calling_method := flow_constants_pkg.gc_dgrm_version_latest_version;
    else
      -- dgrm_version was specified - use 'namedVersion' call...                                                      
      l_calling_method := flow_constants_pkg.gc_dgrm_version_named_version;
    end if;

    -- get the released diagram or 'draft' version '0' diagram (or error...)
    l_dgrm_id := flow_diagram.get_current_diagram ( pi_dgrm_name            => pi_dgrm_name 
                                                  , pi_dgrm_calling_method  => l_calling_method
                                                  , pi_dgrm_version         => pi_dgrm_version
                                                  );

    return  flow_instances.create_process
            ( p_dgrm_id   => l_dgrm_id
            , p_prcs_name => pi_prcs_name
            );
  end flow_create;

  function flow_create
  (
    pi_dgrm_id   in flow_diagrams.dgrm_id%type
  , pi_prcs_name in flow_processes.prcs_name%type
  ) return flow_processes.prcs_id%type
  is
    l_ret flow_processes.prcs_id%type;
  begin
    return flow_instances.create_process
           ( p_dgrm_id => pi_dgrm_id
           , p_prcs_name => pi_prcs_name
           )
    ;
  end flow_create;

  procedure flow_create
  (
    pi_dgrm_name in flow_diagrams.dgrm_name%type
  , pi_dgrm_version in flow_diagrams.dgrm_version%type default null
  , pi_prcs_name in flow_processes.prcs_name%type
  )
  as
    l_prcs_id flow_processes.prcs_id%type;
  begin
    l_prcs_id :=
      flow_create
      (
        pi_dgrm_name => pi_dgrm_name
      , pi_dgrm_version => pi_dgrm_version
      , pi_prcs_name => pi_prcs_name
      );
  end flow_create;

  procedure flow_create
  (
    pi_dgrm_id   in flow_diagrams.dgrm_id%type
  , pi_prcs_name in flow_processes.prcs_name%type
  )
  as
    l_prcs_id flow_processes.prcs_id%type;
  begin
    l_prcs_id :=
      flow_instances.create_process
      (
        p_dgrm_id   => pi_dgrm_id
      , p_prcs_name => pi_prcs_name
      );
  end flow_create;

  procedure flow_start
    ( p_process_id in flow_processes.prcs_id%type
    )
    is
      l_session_id   number;
    begin  
        if v('APP_SESSION') is null then
          l_session_id := flow_apex_session.create_api_session (p_process_id => p_process_id);
        end if;

        apex_debug.message(p_message => 'Begin flow_start', p_level => 3) ;

        flow_globals.set_context
        ( pi_prcs_id => p_process_id
        , pi_scope   => 0   -- initial scope is always 0
        );
  
        flow_instances.start_process 
        ( p_process_id => p_process_id
        );

        if l_session_id is not null then
          flow_apex_session.delete_session (p_session_id => l_session_id );
        end if;
    exception
      when others then
        if l_session_id is not null then
          flow_apex_session.delete_session (p_session_id => l_session_id );
        end if;
        raise;
  end flow_start;

  procedure flow_reserve_step
  ( p_process_id    in flow_processes.prcs_id%type
  , p_subflow_id    in flow_subflows.sbfl_id%type
  , p_step_key      in flow_subflows.sbfl_step_key%type default null
  , p_reservation   in flow_subflows.sbfl_reservation%type
  )
  is 
  begin

    flow_reservations.reserve_step
    ( p_process_id  => p_process_id
    , p_subflow_id  => p_subflow_id
    , p_reservation => p_reservation
    , p_step_key    => p_step_key
    );
  end flow_reserve_step;

  procedure flow_release_step
  ( p_process_id    in flow_processes.prcs_id%type
  , p_subflow_id    in flow_subflows.sbfl_id%type
  , p_step_key      in flow_subflows.sbfl_step_key%type default null
  )
  is 
  begin

    flow_reservations.release_step
    ( p_process_id => p_process_id
    , p_subflow_id => p_subflow_id
    , p_step_key   => p_step_key
    );
  end flow_release_step;

  procedure flow_start_step
  (
    p_process_id    in flow_processes.prcs_id%type
  , p_subflow_id    in flow_subflows.sbfl_id%type
  , p_step_key      in flow_subflows.sbfl_step_key%type default null
  )
  is 
  begin
    flow_engine.start_step
    ( p_process_id  => p_process_id
    , p_subflow_id  => p_subflow_id
    , p_step_key    => p_step_key
    );
  end flow_start_step;

  procedure flow_restart_step
  (
    p_process_id    in flow_processes.prcs_id%type
  , p_subflow_id    in flow_subflows.sbfl_id%type
  , p_step_key      in flow_subflows.sbfl_step_key%type default null
  , p_comment       in flow_instance_event_log.lgpr_comment%type default null
  )
  is 
    l_session_id   number;
  begin 
    -- create an APEX session if this has come in from outside APEX
    if v('APP_SESSION') is null then
      l_session_id := flow_apex_session.create_api_session (p_subflow_id => p_subflow_id);
    end if;

    flow_globals.set_context
    ( pi_prcs_id  => p_process_id
    , pi_sbfl_id  => p_subflow_id
    , pi_step_key => p_step_key
    , pi_scope    => flow_engine_util.get_scope (p_process_id => p_process_id, p_subflow_id => p_subflow_id)
    );
    flow_engine.restart_step
    ( p_process_id => p_process_id
    , p_subflow_id => p_subflow_id
    , p_step_key   => p_step_key
    , p_comment    => p_comment
    );

    if l_session_id is not null then
      flow_apex_session.delete_session (p_session_id => l_session_id );
    end if;
  exception
    when others then
      if l_session_id is not null then
        flow_apex_session.delete_session (p_session_id => l_session_id );
      end if;
      raise;
  end flow_restart_step;


  procedure flow_complete_step
  ( p_process_id    in flow_processes.prcs_id%type
  , p_subflow_id    in flow_subflows.sbfl_id%type
  , p_step_key      in flow_subflows.sbfl_step_key%type default null
  )
  is 
      l_session_id   number;
  begin
    -- create an APEX session if this has come in from outside APEX
    if v('APP_SESSION') is null then
      l_session_id := flow_apex_session.create_api_session (p_subflow_id => p_subflow_id);
    end if; 

    flow_globals.set_context
    ( pi_prcs_id  => p_process_id
    , pi_sbfl_id  => p_subflow_id
    , pi_step_key => p_step_key
    , pi_scope    => flow_engine_util.get_scope (p_process_id => p_process_id, p_subflow_id => p_subflow_id)
    );
    flow_engine.flow_complete_step
    ( p_process_id => p_process_id
    , p_subflow_id => p_subflow_id
    , p_step_key   => p_step_key
    , p_recursive_call => false
    );

    if l_session_id is not null then
      flow_apex_session.delete_session (p_session_id => l_session_id );
    end if;
  exception
    when others then
      if l_session_id is not null then
        flow_apex_session.delete_session (p_session_id => l_session_id );
      end if;
      raise;
  end flow_complete_step;

  procedure flow_reschedule_timer
  (
      p_process_id    in flow_processes.prcs_id%type
    , p_subflow_id    in flow_subflows.sbfl_id%type
    , p_step_key      in flow_subflows.sbfl_step_key%type default null
    , p_is_immediate  in boolean default false
    , p_new_timestamp in flow_timers.timr_start_on%type default null
    , p_comment       in flow_instance_event_log.lgpr_comment%type default null
  )
  is
  begin
    flow_timers_pkg.reschedule_timer
    ( 
      p_process_id    => p_process_id
    , p_subflow_id    => p_subflow_id
    , p_step_key      => p_step_key 
    , p_is_immediate  => p_is_immediate
    , p_new_timestamp => p_new_timestamp
    , p_comment       => p_comment
    );
  end flow_reschedule_timer;

  procedure flow_reset
  ( p_process_id in flow_processes.prcs_id%type
  , p_comment     in flow_instance_event_log.lgpr_comment%type default null
  )
  is
  begin
    apex_debug.enter 
    ( p_routine_name => 'flow_reset'
    );
    flow_instances.reset_process 
    ( p_process_id  => p_process_id
    , p_comment     => p_comment
    );
  end flow_reset;

  procedure flow_terminate
  ( p_process_id  in flow_processes.prcs_id%type
  , p_comment     in flow_instance_event_log.lgpr_comment%type default null
  )
  is
  begin
    apex_debug.enter 
    ( p_routine_name => 'flow_terminate'
    );
    flow_instances.terminate_process 
    ( p_process_id => p_process_id
    , p_comment    => p_comment
    );
  end flow_terminate;

  procedure flow_delete
  ( p_process_id  in flow_processes.prcs_id%type
  , p_comment     in flow_instance_event_log.lgpr_comment%type default null
  )
  is
  begin
    apex_debug.enter
    (p_routine_name => 'flow_delete'
    );
    flow_instances.delete_process 
    ( p_process_id => p_process_id
    , p_comment    => p_comment
    );
  end flow_delete;

  function get_current_usertask_url
  (
    p_process_id in flow_processes.prcs_id%type
  , p_subflow_id in flow_subflows.sbfl_id%type
  , p_step_key      in flow_subflows.sbfl_step_key%type default null
  ) return varchar2
  as
    l_objt_id flow_objects.objt_id%type;
  begin
    apex_debug.trace ( p_message => 'Entering GET_CURRENT_USERTASK_URL' );

    select objt.objt_id
      into l_objt_id
      from flow_subflows sbfl
      join flow_processes prcs
        on prcs.prcs_id = sbfl.sbfl_prcs_id
      join flow_objects objt
        on objt.objt_dgrm_id = prcs.prcs_dgrm_id
       and objt.objt_bpmn_id = sbfl.sbfl_current
     where sbfl.sbfl_prcs_id = p_process_id
       and sbfl.sbfl_id = p_subflow_id
       and objt.objt_tag_name = flow_constants_pkg.gc_bpmn_usertask
    ;

    apex_debug.trace( p_message => 'Found OBJT_ID %s', p0 => l_objt_id );

    return 
      flow_usertask_pkg.get_url
      (
        pi_prcs_id  => p_process_id
      , pi_sbfl_id  => p_subflow_id
      , pi_step_key => p_step_key
      , pi_objt_id  => l_objt_id
      );
  end get_current_usertask_url;

  function message
  ( p_message_key    in varchar2
  , p_lang            in varchar2 default 'en'
  , p0                in varchar2 default null
  , p1                in varchar2 default null
  , p2                in varchar2 default null
  , p3                in varchar2 default null
  , p4                in varchar2 default null
  , p5                in varchar2 default null
  , p6                in varchar2 default null
  , p7                in varchar2 default null
  , p8                in varchar2 default null
  , p9                in varchar2 default null
  ) return varchar2
  is
  begin
    return flow_errors.make_error_message
           ( pi_message_key => p_message_key
           , pi_lang        => p_lang
           , p0   => p0
           , p1   => p1
           , p2   => p2
           , p3   => p3
           , p4   => p4
           , p5   => p5
           , p6   => p6
           , p7   => p7
           , p8   => p8
           , p9   => p9
           );

  end message;

end flow_api_pkg;
/
