% �°���ʱģ�⼰�ƻ��޸�ģ�����
% Ԥ����

clear;close all; clc;tic
% fid = fopen([output_dir,'������.txt'],'w');% �򿪼�����
fid =1;
fprintf(fid,'%s','��ʼ����');fprintf(fid,'\r\n');
lib_directory='C:\Users\hc042\Desktop\renxingjisuancode2\';fprintf(fid,'%s',['load=',lib_directory]);fprintf(fid,'\r\n');
funcName = 'newEPS';
libName = 'epanet2';hfileName = 'epanet2.h';fprintf(fid,'%s',['load  ',libName,'/',hfileName]);fprintf(fid,'\r\n');
if libisloaded(libName)
    unloadlibrary (libName)
end
loadlibrary(libName,hfileName);
try
    load  EPA_F
catch
    path('C:\Users\hc042\Desktop\renxingjisuancode2\toolkit',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\readNet',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\damageNet',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\EPS',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\getValue',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\eventTime',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\random',path);
    path('C:\Users\hc042\Desktop\renxingjisuancode2\random_singleTime',path);%����ģ������ĺ�����
    load  EPA_F2
end
input_net_filename = 'net01.inp';
damage_file = 'damage.txt';
damage_net = 'damage_net.inp';

output_dir=['C:\Users\hc042\Desktop\������','\222\',];
if isdir(output_dir)
    rmdir(output_dir,'s')
end
mkdir(output_dir);
%PDD=============
Hmin=0;%Hmin�ڵ���Сѹ��
Hdes=10;%Hdes�ڵ�����ѹ��;
doa=0.01;%PDD���㾫��
circulation_num=40;%PDDѭ������
% repair=================
RepairCrew={'a'};
pipeStatus = [2,1,1,1,0,0,0;
    2,2,2,2,1,0,0];
time = [0,3600,7200,10800,14400,18000,21600];
%=======================
% EPA_format_filename = 'EPA_FORMAT5.txt';
% fid=fopen(EPA_format_filename,'r'); %��EPAˮ��ģ���ļ������ݴ洢��ʽ������
% EPA_format=textscan(fid,'%q%q%q%q','delimiter',';');%��ȡinp�ļ��еĹؼ��ʼ����ݴ洢���͸�ʽ���ļ���
% fclose(fid);
% save EPA_F2 EPA_format
%=======================

[t1, net_data ] = read_net( input_net_filename,EPA_format);
if t1
    keyboard
end
[t_e,damage_pipe_info]=ND_Execut_deterministic(net_data,'damage.txt');
t_w = write_Damagefile(damage_pipe_info,'damage2.txt');
if t_e&&t_w
    disp('errors==================');
    keyboard
end
[t_W,pipe_relative]=damageNetInp2_GIRAFFE2(net_data,damage_pipe_info,EPA_format,damage_net);
% ��ʱģ��
node_id = net_data{2,2}(:,1);%�ƻ�ǰ�ڵ�����
original_junction_num = numel(node_id);%�ƻ�ǰ�ڵ���Ŀ
link_id = net_data{5,2}(:,1);%�ƻ�ǰ��������
t=calllib('epanet2','ENopen',damage_net,[output_dir,'1.rpt'],[output_dir,'1.out']);
% value =  libpointer('singlePtr',100);
% [c,value] = calllib(libName,'ENgetlinkvalue',1,11,value)
% type = libpointer('int32Ptr',100)
% [c,type] = calllib(libName,'ENgetlinktype',5,type)
if t
    disp('errors==================');
    disp(num2str(t));
end
t1 = calllib('epanet2','ENopenH');
code = calllib('epanet2','ENinitH',0);
n_j =0;
n_r=0;
[c,n_j] = calllib('epanet2','ENgetcount',0,n_j);
[c,n_r] = calllib('epanet2','ENgetcount',1,n_r);
junction_num =n_j -n_r;
temp_t =0;
temp_tstep =1;
time_step_n=0;
% PipeStatus=[time;pipeStatus];
PipeStatus=[pipeStatus];
[newPipeStatus ,timeStepChose]= pipeStatusChange(PipeStatus);
while (temp_tstep &&~code)
    time_step_n=time_step_n+1;
    [code,temp_t]=calllib('epanet2','ENrunH',temp_t);%����
    if code
        disp(['������룺',num2str(code)]);
        keyboard
    end
    [~,based_demand]=Get(junction_num,1);%������ˮ��
    [~,real_demand]=Get(junction_num,9);%ʵ����ˮ��
    [~,real_pre]=Get(junction_num,11);%ˮѹ
    [~,real_demand_chosen]=Get_chosen_node_value(original_junction_num,node_id);
    %     if find(real_pre<Hdes) %���ֵ�ѹ�����PDD����
    [pre,dem] = EPS_PDD2(circulation_num,doa,Hmin,Hdes,net_data,temp_t,real_demand,based_demand,real_demand_chosen);
    %     end
    time_step_n_cell{time_step_n} =time_step_n;
    TimeStep{time_step_n} =double(temp_t);
    Pressure{time_step_n} = double(pre);
    Demand{time_step_n}=double(dem);
    %      len = Get_chosen_link_value(link_id);
    %=============================================
    disp(num2str(temp_t))
    [lia,loc] = ismember(time_step_n,timeStepChose);
    if lia
        fprintf(fid,'%s\r\n','��ʼ�޸Ĺܵ�״̬');
        
        mid_status = newPipeStatus(:,loc);
        for i = 1:numel(mid_status)
            pipe_status = mid_status(i);
            switch  pipe_status
                case 2
                    continue %�ùܵ�û���޸�
                case 1
                    %�ܵ�����
                    for j =1:numel(pipe_relative{i,2})% ����Ĺܵ�Ϊ��ǰ�ܵ���������ƻ��ܵ���
                        id = libpointer('cstring',pipe_relative{i,2}{1,j});
                        fprintf(fid,'����ܵ�:%s\r\n',pipe_relative{i,2}{1,j} );
                        index =libpointer('int32Ptr',0);
                        [code,id,index]=calllib('epanet2','ENgetlinkindex',id,index);
                        if code
                            disp(nem2str(code));
                            keyboard
                        end
                        code=calllib('epanet2','ENsetlinkvalue',index,11,0);%�ܵ�id״̬Ϊ�ر�
                        if code
                            disp(nem2str(code));
                            fprintf(fid,'����ܵ�:%s����,����%s\r\n',id,num2str(code) );
                            keyboard
                        end
                    end
                case 0
                    %reopen �ܵ���˵���ùܵ��޸�
                    id=libpointer('cstring',pipe_relative{i,1});
                    index =libpointer('int32Ptr',0);
                    [code,id,index]=calllib('epanet2','ENgetlinkindex',id,index);
                   
                    if code
                        disp(nem2str(code));
                        keyboard
                    end
                    code= calllib('epanet2','ENsetlinkvalue',index,11,1);
                     fprintf(fid,'reopen�ܵ�%s,\r\n',pipe_relative{i,1});
                    if code
                        disp(nem2str(code));
                        fprintf(fid,'reopen�ܵ�:%s����,����%s\r\n',id,num2str(code) );
                        keyboard
                    end
            end
        end
        fprintf(fid,'%sʱ��,�ܵ�״̬�޸����\r\n',num2str(temp_t) );
    else
        fprintf(fid,'%sʱ��,�����޸Ĺܵ�״̬\r\n',num2str(temp_t) );
    end
    
    [code,temp_tstep]=calllib('epanet2','ENnextH',temp_tstep);
end
calllib('epanet2','ENcloseH');
calllib('epanet2','ENsaveH');%����ˮ���ļ�
calllib('epanet2','ENsetreport','NODES ALL'); % �����������ĸ�ʽ
calllib('epanet2','ENreport');
calllib('epanet2','ENclose');
