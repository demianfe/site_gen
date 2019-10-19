
# wrapps around `builder.nim` but uses uielement objects instead of json
import tables, json, strutils
import uuidjs

include karax / prelude
import karax / [kbase, kdom, vdom, karaxdsl]

import uielement, builder, ui_utils, uitemplates
import uilib / message
# complex components
import components / uiedit
import uibuild / builders

# TODO: add an internal id for each component
# handle a tree or a list of components ids and set if it is built or not


var wb: WebBuilder
const containersKind = [UiElementKind.kComponent,
                        UiElementKind.kHeader,
                        UiElementKind.kNavBar,
                        UiElementKind.kNavSection]


proc callBuilder(wb: WebBuilder, elem: UiElement): VNode =
  var el = elem
  if not el.builder.isNil:
    result = el.builder(wb, elem)
  elif el.kind == UiElementKind.kComponent and el.attributes.len > 0:
    echo el.attributes
    result = buildHtml(tdiv())
    result.addAttributes el

  elif el.kind == UiElementKind.kComponent or el.kind == UiElementKind.kComponent:
    for kid in el.children:
      result = callBuilder(wb, kid)

  if not result.isNil:
    for elkid in el.children:
      let kid = callBuilder(wb, elkid)
      if not kid.isNil:
        result.add kid


proc buildElement(uiel: UiElement, viewid: string): VNode =
  var el: UiElement = uiel
  try:
    if el.kind in containersKind:
      if not el.builder.isNil:
        result = el.builder(wb, el)
        # result.addAttributes el
      else:
        result = buildHtml(tdiv())
      result.addAttributes el
      
      for c in el.children:
        let vkid = buildElement(c, viewid)
        if not vkid.isNil:
          result.add vkid
    else:
      if not el.builder.isNil:
        result = wb.callBuilder(el)
        result.addAttributes el
      
  except:
    # TODO:
    var msg = ""
    let e = getCurrentException()
    if not e.isNil:
      msg = e.getStackTrace() #getCurrentExceptionMsg()
    else:
      msg =  getCurrentExceptionMsg()
      
    echo msg
    result = buildHtml(tdiv):
      h4: text "Error -  Element build fail: " & $el.kind
      h6: text getCurrentExceptionMsg()
      p: text msg
    

proc updateUI*(app: var App): VNode =
  var
    state = app.ctxt.state
    view = state["view"]
    viewid = view["id"].getStr
    route, action: string
    req = Request()
      
  result = newVNode VnodeKind.tdiv
  result.class = "container"
  
  if app.ctxt.messages.len > 0:
    var c = 0
    for m in app.ctxt.messages:
      result.add buildElement(Message(m.kind, m.content, id= $c), viewid)
      c += 1
  
  if state.hasKey("route") and state["route"].getStr != "":
    let
      sr = state["route"].getStr.split("?")

    if sr.len > 1:
      let qs = sr[1].split("&")
      for q in qs:
        let kv = q.split("=")
        if kv.len > 1:
          req.queryString.add kv[0], kv[1]
        else:
          req.queryString.add kv[0], kv[0]

    app.ctxt.request = req
    # grab the first part of the route
    if sr[0].find("/") == 1:
      let splitRoute = sr[0].split "/"
      # echo splitRoute
      # just asume first item is `#`.
      # use `#` in the ui definition to know it is a route.
      route = splitRoute[0..1].join "/"
      if splitRoute.len > 2: action = splitRoute[2]
    else:
      action = sr[0]

  let h = buildElement(app.layout(app.ctxt), viewid)
  if not h.isNil:
    result.add h
            
    # var el = l
    # el.viewid = viewid
    # case l.kind:
    #   of UiElementKind.kHeader:
    #     let h = buildElement(l, viewid)
    #     if not h.isNil:
    #       result.add h        
    #   of UiElementKind.kBody:
    #     case action
    #     of "edit":
    #       echo route, "/", action
    #       # uiedit
    #       let ui = UiEdit(app.ctxt, viewid, route)
    #       result.add buildElement(ui, viewid)
    #     else:
    #       # No autogenerated ui based on model at the moment          
    #       let cName = route.replace("#/", "")
    #       if app.ctxt.uicomponents.haskey cName:
    #          let ui = app.ctxt.uicomponents[cName](app.ctxt)
    #          result.add buildElement(ui, viewid)
    #          result.addAttributes el
                       
    #       elif app.ctxt.actions.haskey cName:
    #         app.ctxt.actions[cName](%*{"querystring": req.queryString})
    #       else:
    #         echo "nothing to build."
            
    #   else:
    #     # TODO:
    #     echo "Error: Invalid Layout section."


proc initApp*(app: var App, event: proc(uiev: uielement.UiEvent, el: UiElement, viewid: string): proc(ev: Event, n: VNode)): VNode =
  wb = newWebBuilder(event)
  result = updateUI(app)
    
