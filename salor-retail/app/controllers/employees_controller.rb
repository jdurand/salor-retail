# coding: UTF-8

# Salor -- The innovative Point Of Sales Software for your Retail Store
# Copyright (C) 2012-2013  Red (E) Tools LTD
# 
# See license.txt for the license applying to all files within this software.
class EmployeesController < ApplicationController
  before_filter :authify, :only => [:show, :index,:new, :edit, :destroy, :create, :update]
  before_filter :initialize_instance_variables, :except => [:login, :signup]
  before_filter :check_role, :except => [:crumble,:login]
  before_filter :crumble, :except => [:login, :signup]
  cache_sweeper :employee_sweeper, :only => [:create, :update, :destroy]
  def verify
    if params[:password] then
      emp = Employee.login(params[:password])
      if not emp then
        render :text => "NO" and return
      else
        render :json => {:username => emp.username, :id => emp.id} and return
      end
    end
  end
  def clockin
    if params[:password] then
      emp = Employee.login(params[:password])
      if not emp then
        render :text => "NO" and return
      else
        login = EmployeeLogin.where(:employee_id => emp.id).last
        if login and login.logout.nil? then
          render :text => "ALREADY" and return
        end
        emp.start_day
        render :json => {:username => emp.username, :id => emp.id} and return
      end
    end
  end
  def clockout
    if params[:password] then
      emp = Employee.login(params[:password])
      if not emp then
        render :text => "NO" and return
      else
        emp.end_day
        render :json => {:username => emp.username, :id => emp.id} and return
      end
    end
  end
  def signup
    if not AppConfig.signup == true then
      redirect_to :action => :login and return
    end
  end
  def login
      user = Employee.login(params[:code]) 
      user = User.login(params[:code]) if not user
    if user then
      session[:user_id] = user.id
      session[:user_type] = user.class.to_s
      $User = user
      $User.start_day
      # History.record("employee_sign_in",user,5) # disabled this because it would break databse replication as soon as one logs into the mirror machine
      if cr = CashRegister.find_by_ip(request.ip) then
        user.get_meta.update_attribute :cash_register_id, cr.id
      end
       if params[:redirect]
          redirect_to CGI.unescape(params[:redirect]) and return
       elsif not user.last_path.empty?
          redirect_to user.last_path and return 
       else
          if user.role_cache.include? 'stockboy' then
            redirect_to '/shipments' + "?vendor_id=#{user.vendor_id}" and return
          elsif user.role_cache.include? 'cashier' then
            redirect_to '/cash_registers' + "?vendor_id=#{user.vendor_id}" and return
          elsif user.role_cache.include? 'manager' then
            redirect_to "/vendors/#{user.vendor_id}" and return
          else
            redirect_to '/orders/new' and return # always try to go to orders/new
          end
       end
    else
      redirect_to :controller => :home, :action => :index, :notice => "could not find a user with code" and return
    end
  end
  def destroy_login
    @employee = Employee.find_by_id(params[:id].to_s)
    if @employee and @employee.vendor_id == $User.vendor_id then
      login = EmployeeLogin.find_by_id(params[:login].to_s)
      if login.employee_id == @employee.id and $User.role_cache.include? 'manager' then
        login.destroy
      else
        raise "Ids Don't Match" + login.employee.id.to_s + " ---- " + $User.role_cache
      end
    else
      redirect_to :action => :index and return
    end
    redirect_to :action => :show, :id => @employee.id
  end
  # GET /employees
  # GET /employees.xml
  def index
    @employees = $Vendor.employees.scopied.order("created_at desc").page(params[:page]).per(25)
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @employees }
    end
  end

  # GET /employees/1
  # GET /employees/1.xml
  def show
    f, t = assign_from_to(params)
    @from = f
    @to = t
    @employee = Employee.find_by_id(params[:id])
    @employee.make_valid
    add_breadcrumb @employee.username,'employee_path(@employee,:vendor_id => params[:vendor_id])'
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @employee }
    end
  end

  # GET /employees/new
  # GET /employees/new.xml
  def new
    @employee = Employee.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @employee }
    end
  end

  # GET /employees/1/edit
  def edit
    @employee = salor_user.get_employee(params[:id])
    add_breadcrumb @employee.username,'edit_employee_path(@employee,:vendor_id => params[:vendor_id])'
  end

  # POST /employees
  # POST /employees.xml
  def create
    @employee = Employee.new(params[:employee])
    @employee.make_valid
    respond_to do |format|
      if @employee.save
        format.html { redirect_to(:action => 'new', :notice => I18n.t("views.notice.model_create", :model => Employee.model_name.human)) }
        format.xml  { render :xml => @employee, :status => :created, :location => @employee }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @employee.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /employees/1
  # PUT /employees/1.xml
  def update
    @employee = $User.get_employee(params[:id])
    respond_to do |format|
      if @employee.update_attributes(params[:employee])
        @employee.set_role_cache
        @employee.save
        [:cache_drop, :application_js, :header_menu,:vendors_show].each do |c|
          expire_fragment(SalorBase.get_cache_name_for_user(@employee))
        end
        format.html { redirect_to :action => 'edit', :id => @employee.id, :notice => 'Employee was successfully updated.' }
        format.xml  { head :ok }
      else
        format.html { redirect_to :action => 'edit', :id => @employee.id, :notice => "Employee could not be saved." }
        format.xml  { render :xml => @employee.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /employees/1
  # DELETE /employees/1.xml
  def destroy
    @employee = Employee.scopied.find(params[:id])
    @employee.kill

    respond_to do |format|
      format.html { redirect_to :action => 'index' }
      format.xml  { head :ok }
    end
  end
  private 
  def crumble
    @vendor = salor_user.get_vendor(salor_user.meta.vendor_id)
    add_breadcrumb @vendor.name,'vendor_path(@vendor)'
    add_breadcrumb I18n.t("menu.employees"),'employees_index_path(:vendor_id => params[:vendor_id])'
  end
end
