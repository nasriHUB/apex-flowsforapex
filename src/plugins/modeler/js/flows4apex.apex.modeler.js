/* global apex, bpmnModeler */

( function ( $, region, debug, server, message, page ) {
  $.widget( "flows4apex.modeler", {
    options: {
      ajaxIdentifier: null,
      itemsToSubmit: null,
    },

    _create: function () {
      this.changed = false;
      this.regionId = this.element[0].id;
      this.modelerWrap = this.regionId + "_modeler";
      this.canvasId = this.regionId + "_canvas";
      this.propertiesPanelParent = this.regionId + "_properties";

      this.enabledModules = [
        bpmnModeler.customModules.propertiesPanelModule,
        bpmnModeler.customModules.propertiesProviderModule,
        bpmnModeler.customModules.lintModule,
        bpmnModeler.customModules.customPaletteProviderModule,
        bpmnModeler.customModules.translationModule,
        bpmnModeler.customModules.styleModule,
        bpmnModeler.customModules.xmlModule,
        bpmnModeler.customModules.AddExporter
      ];

      this.exporter = {
        name: 'Flows for APEX',
        version: '22.1.0',
      };

      this.moddleExtensions = {
        apex: bpmnModeler.moddleExtensions.apexModdleDescriptor,
      };

      this.linting = {
        bpmnlint: bpmnModeler.linting.apexLinting,
      };

      this.bpmnRenderer = {
        defaultFillColor: "var(--default-fill-color)",
        defaultStrokeColor: "var(--default-stroke-color)",
        defaultLabelColor: "var(--default-stroke-color)",
      };

      this.bpmnModeler$ = new bpmnModeler.Modeler( {
        container: "#" + this.canvasId,
        keyboard: { bindTo: document },
        propertiesPanel: { parent: "#" + this.propertiesPanelParent },
        additionalModules: this.enabledModules,
        moddleExtensions: this.moddleExtensions,
        linting: this.linting,
        bpmnRenderer: this.bpmnRenderer,
        exporter: this.exporter,
      } );

      // prevent click events from bubbling up the dom
      $( "#" + this.modelerWrap ).on( "click", ( event ) => {
        event.stopPropagation();
        return false;
      } );

      // register custom changed handler with APEX
      page.warnOnUnsavedChanges( null, () => {
        return this.changed;
      } );

      region.create( this.regionId, {
        widget: () => {
          return this.element;
        },
        refresh: () => {
          this.refresh();
        },
        loadDiagram: () => {
          this.loadDiagram();
        },
        getModelerInstance: () => {
          return this.bpmnModeler$;
        },
        getEventBus: () => {
          return this.bpmnModeler$.get( "eventBus" );
        },
        save: () => {
          this.save();
        },
        getDiagram: () => this.getDiagram(),
        getSVG: () => this.getSVG(),
        widgetName: "bpmnmodeler",
        type: "flows4apex.modeler",
      } );

      this.refresh();
    },
    loadDiagram: async function () {
      var that = this;
      const bpmnModeler$ = this.bpmnModeler$;
      try {
        var result = await bpmnModeler$.importXML( this.diagramContent );

        if (bpmnModeler$._definitions && (bpmnModeler$._definitions.exporter !== 'Flows for APEX' || (bpmnModeler$._definitions.exporter === 'Flows for APEX' && bpmnModeler$._definitions.exporterVersion != '22.1.0'))) {
          const refactored = bpmnModeler$.get('xmlModule').refactorDiagram(this.diagramContent);
          result = await bpmnModeler$.importXML(refactored);
        }

        const { warnings } = result;

        if ( warnings.length > 0 ) {
          debug.warn( "Warnings during XML Import", warnings );
        }

        this.zoom( "fit-viewport" );
        that.changed = false;
        bpmnModeler$.get( "eventBus" ).on( "commandStack.changed", function () {
          that.changed = true;
        } );
      } catch ( err ) {
        debug.error( "Loading Diagram failed.", err, this.diagram );
      }
    },
    zoom: function ( zoomOption ) {
      this.bpmnModeler$.get( "canvas" ).zoom( zoomOption );
    },
    refresh: function () {
      var that = this;
      debug.info( "Enter Refresh", this.options );
      if ( this.changed ) {
        message.confirm(
          "Model has changed. Discard changes?",
          function ( okPressed ) {
            if ( okPressed ) {
              that._refreshCall();
            }
          }
        );
      } else {
        that._refreshCall();
      }
    },
    getDiagram: async function () {
      var that = this;
      const bpmnModeler$ = that.bpmnModeler$;
      try {
        const result = await bpmnModeler$.saveXML( { format: true } );
        const { xml } = result;
        return xml;
      } catch ( err ) {
        debug.error( "Get Diagram failed.", err );
        throw err;
      }
    },
    getSVG: async function () {
      const bpmnModeler$ = this.bpmnModeler$;
      try {
        const result = await bpmnModeler$.saveSVG( { format: true } );
        const { svg } = result;
        const styledSVG = bpmnModeler$.get('styleModule').addToSVGStyle(svg,'.djs-group { --default-fill-color: white; --default-stroke-color: black; }');
        return styledSVG;
      } catch ( err ) {
        debug.error( "Get SVG failed.", err );
        throw err;
      }
    },
    save: async function () {
      this._saveCall( await this.getDiagram() );
    },
    _refreshCall: function () {
      server
        .plugin(
          this.options.ajaxIdentifier,
          {
            pageItems: $( this.options.itemsToSubmit, apex.gPageContext$ ),
            x01: "LOAD",
          },
          {
            refreshObject: "#" + this.canvasId,
            loadingIndicator: "#" + this.canvasId,
          }
        )
        .then( ( pData ) => {
          this.diagramContent = pData.data.content;
          this.diagramId = pData.data.id;
          this.loadDiagram();
        } );
    },
    _saveCall: function ( xml ) {
      server
        .plugin( this.options.ajaxIdentifier, {
          regions: [
            {
              id: this.regionId,
              data: {
                id: this.diagramId,
                content: xml,
              },
            },
          ],
          x01: "SAVE",
        } )
        .then( ( pData ) => {
          apex.message.clearErrors();
          if ( pData.success ) {
            this.changed = false;
            message.showPageSuccess( pData.message );
          } else {
            message.showErrors( [
              {
                type: "error",
                location: ["page"],
                message: pData.message,
                unsafe: false,
              },
            ] );
          }
        } );
    },
  } );
} )( apex.jQuery, apex.region, apex.debug, apex.server, apex.message, apex.page );
